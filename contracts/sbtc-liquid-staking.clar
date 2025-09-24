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