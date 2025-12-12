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
  {
    title: (string-ascii 256),
    description: (string-utf8 1024),
    category: (string-ascii 50),
    outcomes: (list 10 (string-utf8 256)),
    outcome-count: uint,
    resolution-date: uint,
    lock-date: uint,
    state: (string-ascii 20),
    total-pool: uint,
    winning-outcome: (optional uint),
    creator: principal,
    created-at: uint
  }
)

;; Track stakes per outcome for each market
;; Aggregates total stakes on each outcome to calculate odds and payouts
(define-map outcome-pools
  { market-id: uint, outcome-index: uint }
  { total-staked: uint, staker-count: uint }
)

;; Track individual user stakes
;; Records each user's prediction and stake amount for claiming winnings
;; after oracle resolves the market
(define-map user-stakes
  { user: principal, market-id: uint, outcome-index: uint }
  { amount: uint, timestamp: uint, claimed: bool }
)

;; Achievement NFT Maps
;; Soulbound tokens that reward Oracle Market participants
;; These NFTs cannot be transferred once earned
(define-map token-owners
  { token-id: uint }
  { owner: principal }
)

(define-map user-achievements
  { user: principal, achievement-type: uint }
  { token-id: uint, earned-at: uint }
)

(define-map achievement-metadata
  { achievement-type: uint }
  {
    name: (string-ascii 50),
    description: (string-utf8 256),
    image-uri: (string-ascii 256),
    enabled: bool
  }
)

(define-map user-achievement-stats
  { user: principal }
  {
    total-predictions: uint,
    total-wins: uint,
    total-stx-earned: uint,
    achievement-count: uint
  }
)

;; ============================================
;; PRIVATE HELPER FUNCTIONS
;; ============================================

(define-private (get-outcome-pool (market-id uint) (outcome-index uint))
  (default-to 
    { total-staked: u0, staker-count: u0 }
    (map-get? outcome-pools { market-id: market-id, outcome-index: outcome-index })
  )
)

(define-private (get-user-stats-or-default (user principal))
  (default-to
    { total-predictions: u0, total-wins: u0, total-stx-earned: u0, achievement-count: u0 }
    (map-get? user-achievement-stats { user: user })
  )
)

;; ============================================
;; PRIVATE FUNCTIONS
;; ============================================

(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-oracle)
  ;; Validates that the caller is the trusted oracle address
  ;; Only oracles can resolve markets in the Oracle Market system
  (is-eq tx-sender (var-get oracle-address))
)

(define-private (calculate-fee (amount uint))
  ;; Calculates the Oracle Market platform fee from the total pool
  ;; Fee is collected during market resolution and sent to treasury
  (/ (* amount (var-get platform-fee-bps)) BPS-DIVISOR)
)

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

(define-read-only (get-market (market-id uint))
  (map-get? markets { market-id: market-id })
)

(define-read-only (get-user-stake (user principal) (market-id uint) (outcome-index uint))
  (map-get? user-stakes { user: user, market-id: market-id, outcome-index: outcome-index })
)

(define-read-only (get-outcome-pool-info (market-id uint) (outcome-index uint))
  (ok (get-outcome-pool market-id outcome-index))
)

(define-read-only (get-current-odds (market-id uint) (outcome-index uint))
  ;; Calculates real-time odds for an outcome based on stake distribution
  ;; Returns odds as basis points (10000 = 100%) for Oracle Market UI display
  (let
    (
      (market (unwrap! (get-market market-id) ERR-MARKET-NOT-FOUND))
      (total-pool (get total-pool market))
      (outcome-pool (get-outcome-pool market-id outcome-index))
      (outcome-staked (get total-staked outcome-pool))
    )
    (if (is-eq total-pool u0)
      (ok u0)
      (ok (/ (* outcome-staked u10000) total-pool))
    )
  )
)

(define-read-only (calculate-potential-winnings (market-id uint) (outcome-index uint) (stake-amount uint))
  ;; Estimates potential payout for a stake on an outcome
  ;; Helps Oracle Market users make informed prediction decisions
  ;; Accounts for platform fees and current pool distribution
  (let
    (
      (market (unwrap! (get-market market-id) ERR-MARKET-NOT-FOUND))
      (total-pool (get total-pool market))
      (outcome-pool (get-outcome-pool market-id outcome-index))
      (outcome-staked (get total-staked outcome-pool))
      (new-outcome-staked (+ outcome-staked stake-amount))
      (new-total-pool (+ total-pool stake-amount))
      (fee (calculate-fee new-total-pool))
      (distributable-pool (- new-total-pool fee))
    )
    (if (is-eq new-outcome-staked u0)
      (ok u0)
      (ok (/ (* distributable-pool stake-amount) new-outcome-staked))
    )
  )
)

(define-read-only (get-contract-info)
  (ok {
    paused: (var-get contract-paused),
    oracle: (var-get oracle-address),
    treasury: (var-get treasury-address),
    fee-bps: (var-get platform-fee-bps),
    next-market-id: (var-get market-id-nonce)
  })
)

(define-read-only (get-market-display-info (market-id uint))
  (let
    (
      (market (unwrap! (get-market market-id) ERR-MARKET-NOT-FOUND))
    )
    (ok {
      market-id: market-id,
      state: (get state market),
      total-pool: (get total-pool market),
      current-block: stacks-block-height
    })
  )
)

;; ============================================
;; READ-ONLY FUNCTIONS - ACHIEVEMENT NFTs
;; ============================================

(define-read-only (get-last-token-id)
  (ok (var-get token-id-nonce))
)

(define-read-only (get-token-uri (token-id uint))
  ;; Find which achievement type this token belongs to by checking user-achievements
  ;; This is a limitation - we'd need to store achievement-type in token-owners for direct lookup
  ;; For now, return a generic response
  (match (map-get? token-owners { token-id: token-id })
    owner-data (ok (some "ipfs://placeholder/achievement.png"))
    ERR-NFT-NOT-FOUND
  )
)

(define-read-only (get-nft-owner (token-id uint))
  (match (map-get? token-owners { token-id: token-id })
    owner-data (ok (some (get owner owner-data)))
    (ok none)
  )
)

(define-read-only (get-user-achievement (user principal) (achievement-type uint))
  (map-get? user-achievements { user: user, achievement-type: achievement-type })
)

(define-read-only (has-achievement (user principal) (achievement-type uint))
  (is-some (get-user-achievement user achievement-type))
)

(define-read-only (get-achievement-metadata-info (achievement-type uint))
  (map-get? achievement-metadata { achievement-type: achievement-type })
)

(define-read-only (get-user-stats-info (user principal))
  (ok (get-user-stats-or-default user))
)

(define-read-only (get-nft-contract-info)
  (ok {
    total-tokens: (var-get token-id-nonce)
  })
)

;; ============================================
;; PUBLIC FUNCTIONS - ADMIN
;; ============================================

(define-public (set-oracle-address (new-oracle principal))
  ;; Updates the trusted oracle address for the Oracle Market
  ;; Only the contract owner can designate who can resolve markets
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (is-standard new-oracle) ERR-INVALID-PRINCIPAL)
    (ok (var-set oracle-address new-oracle))
  )
)

(define-public (set-treasury-address (new-treasury principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (is-standard new-treasury) ERR-INVALID-PRINCIPAL)
    (ok (var-set treasury-address new-treasury))
  )
)

(define-public (set-platform-fee (new-fee-bps uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee-bps u1000) ERR-INVALID-FEE) ;; Max 10%
    (ok (var-set platform-fee-bps new-fee-bps))
  )
)

(define-public (toggle-pause)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (ok (var-set contract-paused (not (var-get contract-paused))))
  )
)

;; ============================================
;; PUBLIC FUNCTIONS - MARKET CREATION
;; ============================================

(define-public (create-market 
  ;; Creates a new prediction market in the Oracle Market platform
  ;; Markets have 2-10 outcomes and require oracle resolution after lock date
  ;; Only admins can create markets to ensure quality control
  (title (string-ascii 256))
  (description (string-utf8 1024))
  (category (string-ascii 50))
  (outcomes (list 10 (string-utf8 256)))
  (resolution-date uint)
  (lock-date uint)
)
  (let
    (
      (new-market-id (var-get market-id-nonce))
      (outcome-count (len outcomes))
    )
    (asserts! (not (var-get contract-paused)) ERR-PAUSED)
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (>= outcome-count u2) ERR-INVALID-OUTCOME-COUNT) ;; At least 2 outcomes
    (asserts! (<= outcome-count u10) ERR-INVALID-OUTCOME-COUNT) ;; Max 10 outcomes
    (asserts! (> (len title) u0) ERR-INVALID-INPUT) ;; Title not empty
    (asserts! (> (len description) u0) ERR-INVALID-INPUT) ;; Description not empty
    (asserts! (> (len category) u0) ERR-INVALID-INPUT) ;; Category not empty
    (asserts! (> resolution-date stacks-block-height) ERR-INVALID-DATE) ;; Future resolution
    (asserts! (> lock-date stacks-block-height) ERR-INVALID-DATE) ;; Future lock
    (asserts! (< lock-date resolution-date) ERR-INVALID-DATE) ;; Lock before resolution
    
    ;; Create the market
    (map-set markets
      { market-id: new-market-id }
      {
        title: title,
        description: description,
        category: category,
        outcomes: outcomes,
        outcome-count: outcome-count,
        resolution-date: resolution-date,
        lock-date: lock-date,
        state: STATE-ACTIVE,
        total-pool: u0,
        winning-outcome: none,
        creator: tx-sender,
        created-at: stacks-block-height
      }
    )
    
    ;; Log market creation event
    (print {
      event: "market-created",
      market-id: new-market-id,
      creator: tx-sender,
      block-height: stacks-block-height
    })
    
    (var-set market-id-nonce (+ new-market-id u1))
    (ok new-market-id)
  )
)

;; ============================================
;; PUBLIC FUNCTIONS - STAKING
;; ============================================

(define-public (place-stake (market-id uint) (outcome-index uint) (stake-amount uint))
  ;; Allows users to stake STX on a market outcome in the Oracle Market
  ;; Stakes determine odds and potential winnings after oracle resolution
  ;; Users can only stake before the market lock date
  (let
    (
      ;; Note: market-id is validated here - unwrap! ensures market exists
      (market (unwrap! (get-market market-id) ERR-MARKET-NOT-FOUND))
      (market-state (get state market))
      (outcome-count (get outcome-count market))
      (lock-date (get lock-date market))
      (current-pool (get-outcome-pool market-id outcome-index))
      (existing-stake (map-get? user-stakes { user: tx-sender, market-id: market-id, outcome-index: outcome-index }))
    )
    (asserts! (not (var-get contract-paused)) ERR-PAUSED)
    (asserts! (is-eq market-state STATE-ACTIVE) ERR-MARKET-CLOSED)
    (asserts! (< stacks-block-height lock-date) ERR-MARKET-LOCKED)
    (asserts! (< outcome-index outcome-count) ERR-INVALID-OUTCOME)
    (asserts! (>= stake-amount MIN-STAKE) ERR-STAKE-TOO-LOW)
    (asserts! (<= stake-amount MAX-STAKE) ERR-STAKE-TOO-HIGH)
    
    ;; Transfer STX from user to contract principal
    ;; In Clarity 4, we need to get the contract's own principal using unwrap!
    (try! (stx-transfer? stake-amount tx-sender (unwrap! (as-contract? () tx-sender) ERR-TRANSFER-FAILED)))
    
    ;; Update outcome pool
    (map-set outcome-pools
      { market-id: market-id, outcome-index: outcome-index }
      {
        total-staked: (+ (get total-staked current-pool) stake-amount),
        staker-count: (if (is-none existing-stake) 
                        (+ (get staker-count current-pool) u1)
                        (get staker-count current-pool))
      }
    )
    
    ;; Update or create user stake
    (match existing-stake
      prev-stake
        (map-set user-stakes
          { user: tx-sender, market-id: market-id, outcome-index: outcome-index }
          {
            amount: (+ (get amount prev-stake) stake-amount),
            timestamp: stacks-block-height,
            claimed: false
          }
        )
      (map-set user-stakes
        { user: tx-sender, market-id: market-id, outcome-index: outcome-index }
        {
          amount: stake-amount,
          timestamp: stacks-block-height,
          claimed: false
        }
      )
    )
    
    ;; Update market total pool
    (map-set markets
      { market-id: market-id }
      (merge market { total-pool: (+ (get total-pool market) stake-amount) })
    )
    
    ;; Log stake event
    (print {
      event: "stake-placed",
      user: tx-sender,
      market-id: market-id,
      outcome-index: outcome-index,
      amount: stake-amount,
      block-height: stacks-block-height
    })