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