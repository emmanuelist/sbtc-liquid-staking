;; sBTC Liquid Staking Protocol
;; Allows users to stake sBTC and receive liquid staking tokens (lstBTC)
;; Users earn stacking rewards while maintaining liquidity through tradeable lstBTC

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-balance (err u101))
(define-constant err-insufficient-liquidity (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-slippage-exceeded (err u104))
(define-constant err-pool-not-active (err u105))

;; Data Variables
(define-data-var total-sbtc-staked uint u0)
(define-data-var total-lstbtc-supply uint u0)
(define-data-var rewards-accumulated uint u0)
(define-data-var exchange-rate uint u1000000) ;; 1:1 ratio initially (scaled by 1M)
(define-data-var protocol-fee uint u250) ;; 2.5% fee (scaled by 10000)
(define-data-var min-stake-amount uint u1000000) ;; 0.01 sBTC minimum
(define-data-var pool-active bool true)

;; Maps
(define-map user-stakes principal uint)
(define-map user-last-claim principal uint)

;; Fungible Token Definition for lstBTC
(define-fungible-token lstbtc)

;; SIP-010 Token Interface Implementation
(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
    (begin
        (asserts! (is-eq from tx-sender) (err u4))
        (ft-transfer? lstbtc amount from to)
    )
)

(define-read-only (get-name)
    (ok "Liquid Staked Bitcoin")
)

(define-read-only (get-symbol)
    (ok "lstBTC")
)

(define-read-only (get-decimals)
    (ok u8)
)

(define-read-only (get-balance (who principal))
    (ok (ft-get-balance lstbtc who))
)

(define-read-only (get-total-supply)
    (ok (ft-get-supply lstbtc))
)

(define-read-only (get-token-uri)
    (ok none)
)

;; Core Staking Functions

;; Stake sBTC and receive lstBTC
(define-public (stake-sbtc (amount uint))
    (let (
        (current-rate (var-get exchange-rate))
        (lstbtc-to-mint (/ (* amount u1000000) current-rate))
        (sender tx-sender)
    )
        (asserts! (var-get pool-active) err-pool-not-active)
        (asserts! (>= amount (var-get min-stake-amount)) err-invalid-amount)
        
        ;; Transfer sBTC from user to contract
        ;; Note: In production, this would use the actual sBTC token contract
        ;; For now, we'll track the balance in our map
        (map-set user-stakes sender (+ (default-to u0 (map-get? user-stakes sender)) amount))
        
        ;; Mint lstBTC to user
        (try! (ft-mint? lstbtc lstbtc-to-mint sender))
        
        ;; Update global state
        (var-set total-sbtc-staked (+ (var-get total-sbtc-staked) amount))
        (var-set total-lstbtc-supply (+ (var-get total-lstbtc-supply) lstbtc-to-mint))
        
        (print {
            action: "stake",
            user: sender,
            sbtc-amount: amount,
            lstbtc-minted: lstbtc-to-mint,
            exchange-rate: current-rate
        })
        
        (ok lstbtc-to-mint)
    )
)

;; Unstake lstBTC and receive sBTC
(define-public (unstake-lstbtc (lstbtc-amount uint))
    (let (
        (current-rate (var-get exchange-rate))
        (sbtc-to-return (/ (* lstbtc-amount current-rate) u1000000))
        (sender tx-sender)
        (user-lstbtc-balance (ft-get-balance lstbtc sender))
    )
        (asserts! (var-get pool-active) err-pool-not-active)
        (asserts! (>= user-lstbtc-balance lstbtc-amount) err-insufficient-balance)
        (asserts! (>= (var-get total-sbtc-staked) sbtc-to-return) err-insufficient-liquidity)
        
        ;; Burn lstBTC from user
        (try! (ft-burn? lstbtc lstbtc-amount sender))
        
        ;; Return sBTC to user (update their stake balance)
        (let ((current-stake (default-to u0 (map-get? user-stakes sender))))
            (if (>= current-stake sbtc-to-return)
                (map-set user-stakes sender (- current-stake sbtc-to-return))
                ;; If user's original stake is less than what they're owed, give them the difference from rewards
                (begin
                    (map-delete user-stakes sender)
                    ;; In production, this would transfer from the reward pool
                    true
                )
            )
        )

        ;; Update global state
        (var-set total-sbtc-staked (- (var-get total-sbtc-staked) sbtc-to-return))
        (var-set total-lstbtc-supply (- (var-get total-lstbtc-supply) lstbtc-amount))
        
        (print {
            action: "unstake",
            user: sender,
            lstbtc-burned: lstbtc-amount,
            sbtc-returned: sbtc-to-return,
            exchange-rate: current-rate
        })
        
        (ok sbtc-to-return)
    )
)

;; Admin function to add stacking rewards (increases exchange rate)
(define-public (add-rewards (reward-amount uint))
    (let (
        (current-rewards (var-get rewards-accumulated))
        (current-supply (var-get total-lstbtc-supply))
        (current-staked (var-get total-sbtc-staked))
    )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        
        ;; Calculate new exchange rate
        ;; New rate = (total_sbtc_staked + rewards) / total_lstbtc_supply
        (let ((new-total-value (+ current-staked reward-amount)))
            (if (> current-supply u0)
                (var-set exchange-rate (/ (* new-total-value u1000000) current-supply))
                true
            )
        )
        
        (var-set rewards-accumulated (+ current-rewards reward-amount))
        
        (print {
            action: "rewards-added",
            amount: reward-amount,
            new-exchange-rate: (var-get exchange-rate),
            total-rewards: (var-get rewards-accumulated)
        })
        
        (ok true)
    )
)

;; Read-only functions for frontend integration

(define-read-only (get-exchange-rate)
    (var-get exchange-rate)
)

(define-read-only (get-pool-stats)
    {
        total-sbtc-staked: (var-get total-sbtc-staked),
        total-lstbtc-supply: (var-get total-lstbtc-supply),
        exchange-rate: (var-get exchange-rate),
        rewards-accumulated: (var-get rewards-accumulated),
        pool-active: (var-get pool-active)
    }
)

(define-read-only (get-user-info (user principal))
    {
        original-stake: (default-to u0 (map-get? user-stakes user)),
        lstbtc-balance: (ft-get-balance lstbtc user),
        current-sbtc-value: (/ (* (ft-get-balance lstbtc user) (var-get exchange-rate)) u1000000)
    }
)

(define-read-only (calculate-stake-output (sbtc-amount uint))
    (/ (* sbtc-amount u1000000) (var-get exchange-rate))
)

(define-read-only (calculate-unstake-output (lstbtc-amount uint))
    (/ (* lstbtc-amount (var-get exchange-rate)) u1000000)
)

;; Admin functions

(define-public (set-protocol-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= new-fee u1000) err-invalid-amount) ;; Max 10% fee
        (var-set protocol-fee new-fee)
        (ok true)
    )
)

(define-public (set-min-stake-amount (new-min uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set min-stake-amount new-min)
        (ok true)
    )
)

(define-public (toggle-pool (active bool))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set pool-active active)
        (ok true)
    )
)

;; Emergency functions

(define-public (emergency-pause)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set pool-active false)
        (print { action: "emergency-pause", timestamp: stacks-block-height })
        (ok true)
    )
)

;; Initialize contract
(begin
    (print "sBTC Liquid Staking Protocol initialized")
    (print { 
        contract-owner: contract-owner,
        initial-exchange-rate: (var-get exchange-rate),
        protocol-fee: (var-get protocol-fee)
    })
)