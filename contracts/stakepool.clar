
;; Reputation Staking Protocol - simplified, syntactically-correct version
;; NOTE: This version focuses on correct Clarity syntax for local linting.

;; Response types
(define-constant ERR-UNAUTHORIZED u100)
(define-constant ERR-NOT-ENOUGH-STX u101)
(define-constant ERR-No_UNLOCK u102)
(define-constant ERR-ALREADY-GOV u103)
(define-constant ERR-INVALID-ARG u104)

(define-read-only (get-block-height)
  ;; Stub for local compilation; replace with on-chain block-height access if available.
  u0)

(define-constant BLOCKS_PER_DAY u14400)
(define-constant DEFAULT_UNLOCK_DELAY (* BLOCKS_PER_DAY u7))

(define-data-var admin principal tx-sender)
(define-data-var governance-contract (optional principal) none)
(define-data-var stake-multiplier uint u1)
(define-data-var base-rep uint u0)
(define-data-var decay-per-day uint u0)
(define-data-var unlock-delay uint DEFAULT_UNLOCK_DELAY)

(define-map stakes { user: principal } { amount: uint })
(define-map rep-adjust { user: principal } { adj: int })
(define-map unlocks { id: uint } { user: principal, amount: uint, release: uint })
(define-data-var next-unlock-id uint u1)
(define-data-var total-staked uint u0)

(define-read-only (contract-info)
  { name: "Reputation Staking Protocol",
    version: "0.1.0",
    admin: (var-get admin) })

(define-private (is-admin (p principal))
  (is-eq p (var-get admin)))

(define-private (is-governance-or-admin (p principal))
  (let ((gov (var-get governance-contract)))
    (if (is-some gov)
        (or (is-eq p (unwrap-panic gov)) (is-eq p (var-get admin)))
        (is-eq p (var-get admin)))))

(define-private (get-user-stake (who principal))
  (default-to u0 (get amount (map-get? stakes { user: who }))))

(define-private (to-abs (n int))
  (if (< n 0) (* n -1) n))

(define-private (set-user-stake (who principal) (amt uint))
  (if (is-eq amt u0)
      (map-delete stakes { user: who })
      (map-set stakes { user: who } { amount: amt })))

(define-private (increase-total-staked (delta uint))
  (var-set total-staked (+ (var-get total-staked) delta)))

(define-private (decrease-total-staked (delta uint))
  (var-set total-staked (- (var-get total-staked) delta)))

;; NOTE: For simplicity this contract does NOT perform on-chain STX transfers in this stubbed version.

(define-public (stake-amount (amount uint))
  (let ((sender tx-sender)
        (current (get-user-stake sender)))
    (if (<= amount u0)
        (err ERR-INVALID-ARG)
        (let ((new (+ current amount)))
          (asserts! (>= new amount) (err ERR-INVALID-ARG))  ;; Check for overflow
          (set-user-stake sender new)
          (increase-total-staked amount)
          (ok { message: "staked", 
               user: sender, 
               amount: amount, 
               new-stake: new })))))

(define-public (stake-confirm (amount uint))
  (let ((sender tx-sender))
    (begin
      (let ((new (+ (get-user-stake sender) amount)))
        (set-user-stake sender new)
        (increase-total-staked amount)
        (ok (tuple (message "stake-confirmed") (user sender) (amount amount) (new-stake new)))))))

(define-public (request-unstake (amount uint))
  (let ((sender tx-sender)
        (current (get-user-stake tx-sender)))
    (if (< amount u1)
        (err ERR-INVALID-ARG)
        (if (< current amount)
            (err ERR-NOT-ENOUGH-STX)
            (let ((id (var-get next-unlock-id))
                  (release (+ (get-block-height) (var-get unlock-delay))))
              (begin
                (set-user-stake sender (- current amount))
                (map-set unlocks { id: id } { user: sender, amount: amount, release: release })
                (var-set next-unlock-id (+ id u1))
                (ok { message: "unstake-requested",
                     user: sender,
                     amount: amount,
                     unlock-id: id,
                     release: release })))))))

(define-public (withdraw (unlock-id uint))
  (let ((entry (map-get? unlocks { id: unlock-id })))
    (if (is-none entry)
        (err ERR-No_UNLOCK)
        (let ((who (get user (unwrap-panic entry)))
              (amount (get amount (unwrap-panic entry)))
              (release (get release (unwrap-panic entry))))
          (if (<= release (get-block-height))
              (begin
                (map-delete unlocks { id: unlock-id })
                (decrease-total-staked amount)
                ;; In a full implementation we'd transfer STX here
                (ok { message: "withdrawn", user: who, amount: amount }))
              (err ERR-INVALID-ARG))))))

(define-read-only (get-rep-adjustment (user principal))
  (get adj (default-to { adj: 0 } (map-get? rep-adjust { user: user }))))

(define-read-only (calc-base-rep (stake-amt uint))
  (let ((mult (var-get stake-multiplier)) (b (var-get base-rep)))
    (+ b (* stake-amt mult))))

(define-read-only (get-reputation (user principal))
  (let ((base (calc-base-rep (get-user-stake user))) (adj (get-rep-adjustment user)))
    (if (> adj 0)
        (+ base (to-uint (to-abs adj)))
        (if (< adj 0)
            (let ((neg (to-uint (to-abs adj))))
              (if (> base neg) (- base neg) u0))
            base))))

(define-public (adjust-reputation (user principal) (delta int))
  (if (is-governance-or-admin tx-sender)
      (begin
        (let ((existing (get adj (default-to { adj: 0 } (map-get? rep-adjust { user: user })))))
          (map-set rep-adjust { user: user } { adj: (+ existing delta) })
          (ok { message: "rep-adjusted", user: user, delta: delta })))
      (err ERR-UNAUTHORIZED)))

(define-public (slash (user principal) (amount uint) (reason (buff 128)))
  (let ((is-authorized (is-governance-or-admin tx-sender)))
    (if is-authorized
        (let ((current (get-user-stake user)))
          (if (< current amount)
              (err ERR-NOT-ENOUGH-STX)
              (let ((new (- current amount)))
                (begin
                  (set-user-stake user new)
                  (decrease-total-staked amount)
                  (ok { message: "slashed", user: user, amount: amount })))))
        (err ERR-UNAUTHORIZED))))

(define-public (set-governance (gov principal))
  (if (is-admin tx-sender)
      (begin
        (if (is-some (var-get governance-contract))
            (err ERR-ALREADY-GOV)
            (begin
              (var-set governance-contract (some gov))
              (ok { message: "governance-set", gov: gov }))))
      (err ERR-UNAUTHORIZED)))

(define-public (unset-governance)
  (if (is-admin tx-sender)
      (begin
        (var-set governance-contract none)
        (ok { message: "governance-unset" }))
      (err ERR-UNAUTHORIZED)))

(define-public (set-stake-multiplier (m uint))
  (if (is-admin tx-sender)
      (begin 
        (var-set stake-multiplier m)
        (ok { message: "multiplier-set", multiplier: m }))
      (err ERR-UNAUTHORIZED)))

(define-public (set-base-rep (b uint))
  (if (is-admin tx-sender)
      (begin
        (var-set base-rep b)
        (ok { message: "base-rep-set", base: b }))
      (err ERR-UNAUTHORIZED)))

(define-public (set-decay-per-day (d uint))
  (if (is-admin tx-sender)
      (begin
        (var-set decay-per-day d)
        (ok { message: "decay-set", decay: d }))
      (err ERR-UNAUTHORIZED)))

(define-public (set-unlock-delay (blocks uint))
  (if (is-admin tx-sender)
      (begin
        (var-set unlock-delay blocks)
        (ok { message: "unlock-delay-set", blocks: blocks }))
      (err ERR-UNAUTHORIZED)))

(define-public (apply-decay (users (list 10 principal)))
  (let ((decay (var-get decay-per-day)))
    (if (is-eq decay u0)
        (ok (tuple (message "decay-zero")))
        ;; For simplicity this stub acknowledges the request but does not
        ;; apply per-user adjustments in this simplified version.
        (ok (tuple (message "decay-applied") (count (len users)))))))

(define-read-only (get-stake (user principal)) (get-user-stake user))
(define-read-only (get-total-staked) (var-get total-staked))
(define-read-only (get-unlock (id uint)) (map-get? unlocks { id: id }))

(begin
  (var-set admin tx-sender)
  (ok true))
