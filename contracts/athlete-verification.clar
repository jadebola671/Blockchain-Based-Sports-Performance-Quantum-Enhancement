;; Athlete Verification Contract
;; Validates quantum-enhanced athletes and manages their registration

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ATHLETE_EXISTS (err u101))
(define-constant ERR_ATHLETE_NOT_FOUND (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Athlete status types
(define-constant STATUS_PENDING u0)
(define-constant STATUS_VERIFIED u1)
(define-constant STATUS_SUSPENDED u2)
(define-constant STATUS_BANNED u3)

;; Data structures
(define-map athletes
  { athlete-id: principal }
  {
    name: (string-ascii 50),
    sport: (string-ascii 30),
    status: uint,
    verification-date: uint,
    quantum-level: uint,
    medical-clearance: bool
  }
)

(define-map athlete-stats
  { athlete-id: principal }
  {
    total-enhancements: uint,
    safety-violations: uint,
    competition-wins: uint,
    last-enhancement: uint
  }
)

(define-data-var total-athletes uint u0)

;; Register new athlete
(define-public (register-athlete (name (string-ascii 50)) (sport (string-ascii 30)))
  (let ((athlete-id tx-sender))
    (asserts! (is-none (map-get? athletes { athlete-id: athlete-id })) ERR_ATHLETE_EXISTS)
    (map-set athletes
      { athlete-id: athlete-id }
      {
        name: name,
        sport: sport,
        status: STATUS_PENDING,
        verification-date: block-height,
        quantum-level: u0,
        medical-clearance: false
      }
    )
    (map-set athlete-stats
      { athlete-id: athlete-id }
      {
        total-enhancements: u0,
        safety-violations: u0,
        competition-wins: u0,
        last-enhancement: u0
      }
    )
    (var-set total-athletes (+ (var-get total-athletes) u1))
    (ok athlete-id)
  )
)

;; Verify athlete (admin only)
(define-public (verify-athlete (athlete-id principal) (quantum-level uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? athletes { athlete-id: athlete-id })) ERR_ATHLETE_NOT_FOUND)
    (map-set athletes
      { athlete-id: athlete-id }
      (merge (unwrap-panic (map-get? athletes { athlete-id: athlete-id }))
        {
          status: STATUS_VERIFIED,
          quantum-level: quantum-level,
          medical-clearance: true,
          verification-date: block-height
        }
      )
    )
    (ok true)
  )
)

;; Update athlete status
(define-public (update-athlete-status (athlete-id principal) (new-status uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? athletes { athlete-id: athlete-id })) ERR_ATHLETE_NOT_FOUND)
    (asserts! (<= new-status STATUS_BANNED) ERR_INVALID_STATUS)
    (map-set athletes
      { athlete-id: athlete-id }
      (merge (unwrap-panic (map-get? athletes { athlete-id: athlete-id }))
        { status: new-status }
      )
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-athlete (athlete-id principal))
  (map-get? athletes { athlete-id: athlete-id })
)

(define-read-only (get-athlete-stats (athlete-id principal))
  (map-get? athlete-stats { athlete-id: athlete-id })
)

(define-read-only (is-athlete-verified (athlete-id principal))
  (match (map-get? athletes { athlete-id: athlete-id })
    athlete-data (is-eq (get status athlete-data) STATUS_VERIFIED)
    false
  )
)

(define-read-only (get-total-athletes)
  (var-get total-athletes)
)
