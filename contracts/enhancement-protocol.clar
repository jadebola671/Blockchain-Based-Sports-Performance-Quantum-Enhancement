;; Enhancement Protocol Contract
;; Manages quantum performance enhancement procedures

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_ATHLETE_NOT_VERIFIED (err u201))
(define-constant ERR_ENHANCEMENT_LIMIT (err u202))
(define-constant ERR_COOLDOWN_ACTIVE (err u203))
(define-constant ERR_PROTOCOL_NOT_FOUND (err u204))

;; Enhancement types
(define-constant ENHANCEMENT_STRENGTH u1)
(define-constant ENHANCEMENT_SPEED u2)
(define-constant ENHANCEMENT_ENDURANCE u3)
(define-constant ENHANCEMENT_AGILITY u4)
(define-constant ENHANCEMENT_FOCUS u5)

;; Protocol configurations
(define-map enhancement-protocols
  { protocol-id: uint }
  {
    name: (string-ascii 50),
    enhancement-type: uint,
    quantum-intensity: uint,
    duration-blocks: uint,
    cooldown-blocks: uint,
    max-uses-per-day: uint,
    safety-rating: uint
  }
)

(define-map athlete-enhancements
  { athlete-id: principal, enhancement-id: uint }
  {
    protocol-id: uint,
    start-block: uint,
    end-block: uint,
    intensity-used: uint,
    status: uint
  }
)

(define-map daily-enhancement-count
  { athlete-id: principal, day: uint }
  { count: uint }
)

(define-data-var next-enhancement-id uint u1)
(define-data-var next-protocol-id uint u1)

;; Create enhancement protocol (admin only)
(define-public (create-protocol
  (name (string-ascii 50))
  (enhancement-type uint)
  (quantum-intensity uint)
  (duration-blocks uint)
  (cooldown-blocks uint)
  (max-uses-per-day uint)
  (safety-rating uint))
  (let ((protocol-id (var-get next-protocol-id)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set enhancement-protocols
      { protocol-id: protocol-id }
      {
        name: name,
        enhancement-type: enhancement-type,
        quantum-intensity: quantum-intensity,
        duration-blocks: duration-blocks,
        cooldown-blocks: cooldown-blocks,
        max-uses-per-day: max-uses-per-day,
        safety-rating: safety-rating
      }
    )
    (var-set next-protocol-id (+ protocol-id u1))
    (ok protocol-id)
  )
)

;; Apply enhancement to athlete
(define-public (apply-enhancement (athlete-id principal) (protocol-id uint))
  (let (
    (protocol (unwrap! (map-get? enhancement-protocols { protocol-id: protocol-id }) ERR_PROTOCOL_NOT_FOUND))
    (enhancement-id (var-get next-enhancement-id))
    (current-day (/ block-height u144)) ;; Assuming ~144 blocks per day
    (daily-count (default-to { count: u0 } (map-get? daily-enhancement-count { athlete-id: athlete-id, day: current-day })))
  )
    ;; Check if athlete is verified (would need to call athlete-verification contract)
    (asserts! (< (get count daily-count) (get max-uses-per-day protocol)) ERR_ENHANCEMENT_LIMIT)

    ;; Record enhancement
    (map-set athlete-enhancements
      { athlete-id: athlete-id, enhancement-id: enhancement-id }
      {
        protocol-id: protocol-id,
        start-block: block-height,
        end-block: (+ block-height (get duration-blocks protocol)),
        intensity-used: (get quantum-intensity protocol),
        status: u1 ;; Active
      }
    )

    ;; Update daily count
    (map-set daily-enhancement-count
      { athlete-id: athlete-id, day: current-day }
      { count: (+ (get count daily-count) u1) }
    )

    (var-set next-enhancement-id (+ enhancement-id u1))
    (ok enhancement-id)
  )
)

;; Deactivate enhancement
(define-public (deactivate-enhancement (athlete-id principal) (enhancement-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set athlete-enhancements
      { athlete-id: athlete-id, enhancement-id: enhancement-id }
      (merge (unwrap-panic (map-get? athlete-enhancements { athlete-id: athlete-id, enhancement-id: enhancement-id }))
        { status: u0 } ;; Inactive
      )
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-protocol (protocol-id uint))
  (map-get? enhancement-protocols { protocol-id: protocol-id })
)

(define-read-only (get-enhancement (athlete-id principal) (enhancement-id uint))
  (map-get? athlete-enhancements { athlete-id: athlete-id, enhancement-id: enhancement-id })
)

(define-read-only (get-daily-enhancement-count (athlete-id principal) (day uint))
  (default-to { count: u0 } (map-get? daily-enhancement-count { athlete-id: athlete-id, day: day }))
)

(define-read-only (is-enhancement-active (athlete-id principal) (enhancement-id uint))
  (match (map-get? athlete-enhancements { athlete-id: athlete-id, enhancement-id: enhancement-id })
    enhancement (and (is-eq (get status enhancement) u1) (> (get end-block enhancement) block-height))
    false
  )
)
