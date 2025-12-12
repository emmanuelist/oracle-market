;; ============================================
;; ORACLE MARKET - Decentralized Prediction Market
;; ============================================
;; A blockchain-based prediction market platform where users can stake STX
;; on various outcomes of future events. Markets are created by admins and
;; resolved by trusted oracles who verify real-world outcomes.
;; 
;; Key Features:
;; - Oracle-verified market resolution for trustworthy outcomes
;; - Multi-outcome prediction markets (2-10 outcomes per market)
;; - Dynamic odds calculation based on stake distribution
;; - Platform fee collection for sustainable operations
;; - Achievement NFT system to reward active predictors
;; - Soulbound achievement tokens (non-transferable)
;;
;; ============================================
;; CONSTANTS
;; ============================================

;; Error codes - Prediction Market (100-199)
;; These errors handle market operations and oracle interactions
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-MARKET-NOT-FOUND (err u101))
(define-constant ERR-INVALID-MARKET-STATE (err u102))
(define-constant ERR-INVALID-OUTCOME (err u103))
(define-constant ERR-STAKE-TOO-LOW (err u104))
(define-constant ERR-STAKE-TOO-HIGH (err u105))
(define-constant ERR-MARKET-CLOSED (err u106))
(define-constant ERR-MARKET-NOT-RESOLVED (err u107))
(define-constant ERR-NO-WINNINGS (err u108))
(define-constant ERR-ALREADY-CLAIMED (err u109))
(define-constant ERR-INVALID-ORACLE (err u110))
(define-constant ERR-MARKET-LOCKED (err u111))
(define-constant ERR-MARKET-ALREADY-RESOLVED (err u112))
(define-constant ERR-PAUSED (err u113))
(define-constant ERR-INVALID-FEE (err u114))
(define-constant ERR-TRANSFER-FAILED (err u115))
(define-constant ERR-INVALID-PRINCIPAL (err u116))
(define-constant ERR-INVALID-OUTCOME-COUNT (err u117))
(define-constant ERR-INVALID-INPUT (err u118))
(define-constant ERR-INVALID-DATE (err u119))

;; Error codes - Achievement NFTs (200-299)
(define-constant ERR-NFT-NOT-FOUND (err u201))
(define-constant ERR-ALREADY-EXISTS (err u202))
(define-constant ERR-INVALID-ACHIEVEMENT (err u203))
(define-constant ERR-ACHIEVEMENT-LOCKED (err u204))

;; Market states - Define the lifecycle of a prediction market
;; ACTIVE: Market is open for staking
;; LOCKED: Market closed for staking, awaiting oracle resolution
;; RESOLVED: Oracle has determined the winning outcome
;; CANCELLED: Market cancelled, users can claim refunds
(define-constant STATE-ACTIVE "active")
(define-constant STATE-LOCKED "locked")
(define-constant STATE-RESOLVED "resolved")
(define-constant STATE-CANCELLED "cancelled")

;; Staking limits (in microSTX, 1 STX = 1,000,000 microSTX)
(define-constant MIN-STAKE u1000000) ;; 1 STX
(define-constant MAX-STAKE u100000000) ;; 100 STX

;; Platform fee divisor for basis points calculation
(define-constant BPS-DIVISOR u10000)

;; Achievement types - NFT rewards for Oracle Market milestones
;; These soulbound tokens recognize user participation and success
(define-constant ACHIEVEMENT-FIRST-PREDICTION u1)
(define-constant ACHIEVEMENT-FIRST-WIN u2)
(define-constant ACHIEVEMENT-FIVE-WINS u3)
(define-constant ACHIEVEMENT-TEN-WINS u4)
(define-constant ACHIEVEMENT-HUNDRED-STX-EARNED u5)

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; ============================================
;; DATA VARIABLES
;; ============================================

;; Prediction Market Variables
;; Core state variables for Oracle Market operations
(define-data-var market-id-nonce uint u0) ;; Counter for unique market IDs
(define-data-var platform-fee-bps uint u300)
(define-data-var treasury-address principal CONTRACT-OWNER)
(define-data-var contract-paused bool false)
(define-data-var oracle-address principal CONTRACT-OWNER) ;; Trusted oracle who resolves markets

;; Achievement NFT Variables
(define-data-var token-id-nonce uint u0)

;; ============================================
;; DATA MAPS
;; ============================================

;; Market data structure
;; Stores all information about prediction markets in the Oracle Market
;; Markets are created by admins and resolved by oracles
(define-map markets
  { market-id: uint }