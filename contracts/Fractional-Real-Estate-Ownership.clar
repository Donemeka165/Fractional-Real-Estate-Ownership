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