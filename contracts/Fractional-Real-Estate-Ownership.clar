;; Fractional Real Estate Ownership
;; A smart contract that enables fractional ownership of real estate properties

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-property-exists (err u102))
(define-constant err-property-not-found (err u103))
(define-constant err-insufficient-tokens (err u104))
(define-constant err-kyc-required (err u105))
(define-constant err-voting-closed (err u106))
(define-constant err-already-voted (err u107))
(define-constant err-listing-not-found (err u108))
(define-constant err-invalid-price (err u109))
(define-constant err-unauthorized-transfer (err u110))

;; Data structures

;; Property information
(define-map properties
  { property-id: uint }
  {
    property-name: (string-ascii 100),
    location: (string-ascii 100),
    total-tokens: uint,
    valuation: uint,
    rent-period-days: uint,
    last-rent-collection-height: uint,
    kyc-required: bool,
    active: bool
  }
)

;; Token ownership
(define-map token-ownership
  { property-id: uint, owner: principal }
  { token-count: uint }
)

;; Total tokens per property
(define-map property-tokens-total
  { property-id: uint }
  { total-tokens: uint }
)

;; KYC approval status
(define-map kyc-approved
  { user: principal }
  { approved: bool, expiry-height: uint }
)
;; Property governance proposals
(define-map governance-proposals
  { property-id: uint, proposal-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    proposer: principal,
    proposal-type: (string-ascii 20),
    start-block-height: uint,
    end-block-height: uint,
    executed: bool,
    votes-for: uint,
    votes-against: uint
  }
)

;; Voting records
(define-map vote-records
  { property-id: uint, proposal-id: uint, voter: principal }
  { voted: bool, vote-count: uint, support: bool }
)

;; Secondary market listings
(define-map marketplace-listings
  { listing-id: uint }
  {
    seller: principal,
    property-id: uint,
    token-count: uint,
    price-per-token: uint,
    active: bool
  }
)

;; Counter for proposal IDs
(define-data-var next-proposal-id uint u1)

;; Counter for listing IDs
(define-data-var next-listing-id uint u1)

;; Counter for property IDs
(define-data-var next-property-id uint u1)

;; Getters

(define-read-only (get-property (property-id uint))
  (map-get? properties { property-id: property-id })
)

(define-read-only (get-token-balance (property-id uint) (owner principal))
  (default-to u0 
    (get token-count 
      (map-get? token-ownership { property-id: property-id, owner: owner })
    )
  )
)

(define-read-only (get-property-total-tokens (property-id uint))
  (get total-tokens 
    (unwrap! (map-get? properties { property-id: property-id }) (err err-property-not-found))
  )
)

(define-read-only (get-proposal (property-id uint) (proposal-id uint))
  (map-get? governance-proposals { property-id: property-id, proposal-id: proposal-id })
)
(define-read-only (get-marketplace-listing (listing-id uint))
  (map-get? marketplace-listings { listing-id: listing-id })
)

(define-read-only (get-user-kyc-status (user principal))
  (default-to { approved: false, expiry-height: u0 }
    (map-get? kyc-approved { user: user })
  )
)

(define-read-only (is-kyc-valid (user principal))
  (let ((kyc-info (get-user-kyc-status user)))
    (and 
      (get approved kyc-info)
      (< block-height (get expiry-height kyc-info))
    )
  )
)

;; Property Management Functions

(define-public (register-property (name (string-ascii 100)) (location (string-ascii 100)) (total-tokens uint) (valuation uint) (rent-period uint) (kyc-required bool))
  (let ((property-id (var-get next-property-id)))
    ;; Only contract owner can register properties
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> total-tokens u0) (err u111))
    (asserts! (> valuation u0) (err u112))
    
    ;; Register the property
    (map-set properties 
      { property-id: property-id }
      {
        property-name: name,
        location: location,
        total-tokens: total-tokens,
        valuation: valuation,
        rent-period-days: rent-period,
        last-rent-collection-height: block-height,
        kyc-required: kyc-required,
        active: true
      }
    )
    
    ;; Assign all tokens to contract owner initially
    (map-set token-ownership
      { property-id: property-id, owner: contract-owner }
      { token-count: total-tokens }
    )
    
    ;; Increment property ID counter
    (var-set next-property-id (+ property-id u1))
    
    (ok property-id)
  )
)

(define-public (update-property-valuation (property-id uint) (new-valuation uint))
  (let ((property (unwrap! (get-property property-id) err-property-not-found)))
    ;; Only contract owner can update valuation
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> new-valuation u0) (err u112))
    
    ;; Update the property valuation
    (map-set properties 
      { property-id: property-id }
      (merge property { valuation: new-valuation })
    )
    
    (ok true)
  )
)

;; KYC Management

(define-public (set-kyc-approval (user principal) (approved bool) (expiry-blocks uint))
  (begin
    ;; Only contract owner can set KYC status
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    ;; Set KYC status
    (map-set kyc-approved
      { user: user }
      { 
        approved: approved, 
        expiry-height: (+ block-height expiry-blocks)
      }
    )
    
    (ok true)
  )
)

;; Token Transfer Functions

(define-public (transfer-tokens (property-id uint) (recipient principal) (amount uint))
  (let (
    (sender-balance (get-token-balance property-id tx-sender))
    (property (unwrap! (get-property property-id) err-property-not-found))
  )
    ;; Check if sender has enough tokens
    (asserts! (>= sender-balance amount) err-insufficient-tokens)
    
    ;; Check KYC requirements
    (asserts! 
      (or 
        (not (get kyc-required property))
        (and 
          (is-kyc-valid tx-sender)
          (is-kyc-valid recipient)
        )
      ) 
      err-kyc-required
    )
    ;; Update sender balance
    (map-set token-ownership
      { property-id: property-id, owner: tx-sender }
      { token-count: (- sender-balance amount) }
    )
    
    ;; Update recipient balance
    (map-set token-ownership
      { property-id: property-id, owner: recipient }
      { 
        token-count: (+ (get-token-balance property-id recipient) amount) 
      }
    )
    
    (ok true)
  )
)

;; Rent Distribution

(define-public (distribute-rent (property-id uint) (rent-amount uint))
  (let (
    (property (unwrap! (get-property property-id) err-property-not-found))
    (total-tokens (get total-tokens property))
  )
    ;; Only contract owner can distribute rent
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    ;; Update last rent collection timestamp
    (map-set properties 
      { property-id: property-id }
      (merge property { last-rent-collection-height: block-height })
    )
    
    ;; We would distribute the rent here, but since we can't iterate through all token holders
    ;; in Clarity, we would need a different approach or an off-chain component to trigger
    ;; individual rent distribution transactions
    
    ;; For demonstration purposes, we'll just acknowledge the rent distribution
    (ok true)
  )
)

;; Function for token holders to claim their rent
(define-public (claim-rent (property-id uint))
  (let (
    (property (unwrap! (get-property property-id) err-property-not-found))
    (token-balance (get-token-balance property-id tx-sender))
    (total-tokens (get total-tokens property))
  )
    ;; Ensure user has tokens
    (asserts! (> token-balance u0) err-insufficient-tokens)
    
    ;; In a real implementation, this would calculate and transfer the claimable rent
    ;; based on the token balance and rent collected
    
    (ok token-balance)
  )
)

;; Governance Functions

(define-public (create-proposal 
  (property-id uint) 
  (title (string-ascii 100)) 
  (description (string-ascii 500)) 
  (proposal-type (string-ascii 20))
  (voting-period uint)
)
  (let (
    (proposal-id (var-get next-proposal-id))
    (token-balance (get-token-balance property-id tx-sender))
  )
    ;; Check if property exists
    (asserts! (is-some (get-property property-id)) err-property-not-found)
    
    ;; Ensure proposer has tokens
    (asserts! (> token-balance u0) err-insufficient-tokens)
    
    ;; Create proposal
    (map-set governance-proposals
      { property-id: property-id, proposal-id: proposal-id }
      {
        title: title,
        description: description,
        proposer: tx-sender,
        proposal-type: proposal-type,
        start-block-height: block-height,
        end-block-height: (+ block-height voting-period),
        executed: false,
        votes-for: u0,
        votes-against: u0
      }
    )
    
    ;; Increment proposal ID counter
    (var-set next-proposal-id (+ proposal-id u1))
    
    (ok proposal-id)
  )
)

(define-public (vote-on-proposal (property-id uint) (proposal-id uint) (support bool))
  (let (
    (proposal (unwrap! (get-proposal property-id proposal-id) (err u106)))
    (token-balance (get-token-balance property-id tx-sender))
    (vote-record (map-get? vote-records { property-id: property-id, proposal-id: proposal-id, voter: tx-sender }))
  )
    ;; Ensure voting is still open
    (asserts! (< block-height (get end-block-height proposal)) err-voting-closed)
    
    ;; Ensure voter has tokens
    (asserts! (> token-balance u0) err-insufficient-tokens)
    
    ;; Ensure voter hasn't already voted
    (asserts! (or (is-none vote-record) (not (get voted (default-to { voted: false, vote-count: u0, support: false } vote-record)))) err-already-voted)
    
    ;; Record vote
    (map-set vote-records
      { property-id: property-id, proposal-id: proposal-id, voter: tx-sender }
      { voted: true, vote-count: token-balance, support: support }
    )
    
    ;; Update proposal vote counts
    (map-set governance-proposals
      { property-id: property-id, proposal-id: proposal-id }
      (merge proposal {
        votes-for: (if support (+ (get votes-for proposal) token-balance) (get votes-for proposal)),
        votes-against: (if support (get votes-against proposal) (+ (get votes-against proposal) token-balance))
      })
    )
    
    (ok true)
  )
)

(define-public (execute-proposal (property-id uint) (proposal-id uint))
  (let (
    (proposal (unwrap! (get-proposal property-id proposal-id) (err u106)))
  )
    ;; Only contract owner can execute proposals for now
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    ;; Ensure voting period is over
    (asserts! (>= block-height (get end-block-height proposal)) (err u113))
    
    ;; Ensure proposal hasn't been executed
    (asserts! (not (get executed proposal)) (err u114))
    
    ;; Mark proposal as executed
    (map-set governance-proposals
      { property-id: property-id, proposal-id: proposal-id }
      (merge proposal { executed: true })
    )
    
    ;; In a real implementation, we would execute different actions based on proposal type
    ;; For now, we just mark it as executed
    
    (ok true)
  )
)

;; Secondary Market Functions

(define-public (create-listing (property-id uint) (token-count uint) (price-per-token uint))
  (let (
    (listing-id (var-get next-listing-id))
    (token-balance (get-token-balance property-id tx-sender))
  )
    ;; Ensure seller has enough tokens
    (asserts! (>= token-balance token-count) err-insufficient-tokens)
    ;; Ensure valid price
    (asserts! (> price-per-token u0) err-invalid-price)
    
    ;; Create listing
    (map-set marketplace-listings
      { listing-id: listing-id }
      {
        seller: tx-sender,
        property-id: property-id,
        token-count: token-count,
        price-per-token: price-per-token,
        active: true
      }
    )
    
    ;; Increment listing ID counter
    (var-set next-listing-id (+ listing-id u1))
    
    (ok listing-id)
  )
)

(define-public (cancel-listing (listing-id uint))
  (let (
    (listing (unwrap! (get-marketplace-listing listing-id) err-listing-not-found))
  )
    ;; Ensure sender is the seller
    (asserts! (is-eq tx-sender (get seller listing)) err-not-authorized)
    
    ;; Mark listing as inactive
    (map-set marketplace-listings
      { listing-id: listing-id }
      (merge listing { active: false })
    )
    
    (ok true)
  )
)

(define-public (purchase-listing (listing-id uint))
  (let (
    (listing (unwrap! (get-marketplace-listing listing-id) err-listing-not-found))
    (property-id (get property-id listing))
    (token-count (get token-count listing))
    (price-per-token (get price-per-token listing))
    (seller (get seller listing))
    (property (unwrap! (get-property property-id) err-property-not-found))
    (total-price (* token-count price-per-token))
  )
    ;; Ensure listing is active
    (asserts! (get active listing) (err u115))
    
    ;; Check KYC requirements
    (asserts! 
      (or 
        (not (get kyc-required property))
        (and 
          (is-kyc-valid tx-sender)
          (is-kyc-valid seller)
        )
      ) 
      err-kyc-required
    )
    
    ;; In a real implementation, we would handle the STX payment here
    ;; For this demo, we assume payment is handled and directly transfer tokens
    
    ;; Transfer tokens from seller to buyer
    (map-set token-ownership
      { property-id: property-id, owner: seller }
      { token-count: (- (get-token-balance property-id seller) token-count) }
    )
    
    (map-set token-ownership
      { property-id: property-id, owner: tx-sender }
      { token-count: (+ (get-token-balance property-id tx-sender) token-count) }
    )
    
    ;; Mark listing as inactive
    (map-set marketplace-listings
      { listing-id: listing-id }
      (merge listing { active: false })
    )
    
    (ok true)
  )
)

;; Initialize the contract with the deployer as the owner
;