(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_SERVICE (err u101))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u102))
(define-constant ERR_SERVICE_NOT_FOUND (err u103))
(define-constant ERR_SERVICE_ALREADY_COMPLETED (err u104))
(define-constant ERR_SERVICE_ALREADY_PAID (err u105))
(define-constant ERR_INVALID_PROVIDER (err u106))
(define-constant ERR_INVALID_PATIENT (err u107))
(define-constant ERR_SERVICE_NOT_AUTHORIZED (err u108))
(define-constant ERR_REFUND_NOT_ALLOWED (err u109))

(define-data-var next-service-id uint u1)
(define-data-var platform-fee-percentage uint u5)
(define-data-var emergency-surcharge-percentage uint u10)

(define-map ambulance-services
    uint
    {
        patient: principal,
        provider: principal,
        service-type: (string-ascii 50),
        base-cost: uint,
        emergency-level: uint,
        pickup-location: (string-ascii 100),
        destination: (string-ascii 100),
        distance-km: uint,
        created-at: uint,
        completed-at: (optional uint),
        payment-status: (string-ascii 20),
        total-cost: uint,
        platform-fee: uint,
        provider-payment: uint,
    }
)

(define-map authorized-providers
    principal
    {
        name: (string-ascii 100),
        license-number: (string-ascii 50),
        contact: (string-ascii 100),
        rating: uint,
        total-services: uint,
        verified: bool,
        registered-at: uint,
    }
)

(define-map patient-profiles
    principal
    {
        name: (string-ascii 100),
        emergency-contact: (string-ascii 100),
        medical-info: (string-ascii 200),
        total-services: uint,
        total-paid: uint,
        registered-at: uint,
    }
)

(define-map service-payments
    uint
    {
        amount-deposited: uint,
        payment-released: bool,
        refunded: bool,
        deposited-at: uint,
        released-at: (optional uint),
    }
)

(define-map service-reviews
    uint
    {
        rating: uint,
        review: (string-ascii 500),
        reviewed-at: uint,
    }
)

(define-public (register-provider
        (name (string-ascii 100))
        (license-number (string-ascii 50))
        (contact (string-ascii 100))
    )
    (begin
        (map-set authorized-providers tx-sender {
            name: name,
            license-number: license-number,
            contact: contact,
            rating: u50,
            total-services: u0,
            verified: false,
            registered-at: stacks-block-height,
        })
        (ok true)
    )
)

(define-public (register-patient
        (name (string-ascii 100))
        (emergency-contact (string-ascii 100))
        (medical-info (string-ascii 200))
    )
    (begin
        (map-set patient-profiles tx-sender {
            name: name,
            emergency-contact: emergency-contact,
            medical-info: medical-info,
            total-services: u0,
            total-paid: u0,
            registered-at: stacks-block-height,
        })
        (ok true)
    )
)

(define-public (verify-provider (provider principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (match (map-get? authorized-providers provider)
            provider-data (begin
                (map-set authorized-providers provider
                    (merge provider-data { verified: true })
                )
                (ok true)
            )
            ERR_INVALID_PROVIDER
        )
    )
)

(define-public (request-ambulance
        (provider principal)
        (service-type (string-ascii 50))
        (emergency-level uint)
        (pickup-location (string-ascii 100))
        (destination (string-ascii 100))
        (distance-km uint)
    )
    (let (
            (service-id (var-get next-service-id))
            (base-cost (* distance-km u1000))
            (emergency-surcharge (if (> emergency-level u5)
                (/ (* base-cost (var-get emergency-surcharge-percentage)) u100)
                u0
            ))
            (total-cost (+ base-cost emergency-surcharge))
            (platform-fee (/ (* total-cost (var-get platform-fee-percentage)) u100))
            (provider-payment (- total-cost platform-fee))
        )
        (asserts! (is-some (map-get? authorized-providers provider))
            ERR_INVALID_PROVIDER
        )
        (asserts! (is-some (map-get? patient-profiles tx-sender))
            ERR_INVALID_PATIENT
        )
        (asserts!
            (get verified
                (unwrap! (map-get? authorized-providers provider)
                    ERR_INVALID_PROVIDER
                ))
            ERR_SERVICE_NOT_AUTHORIZED
        )

        (map-set ambulance-services service-id {
            patient: tx-sender,
            provider: provider,
            service-type: service-type,
            base-cost: base-cost,
            emergency-level: emergency-level,
            pickup-location: pickup-location,
            destination: destination,
            distance-km: distance-km,
            created-at: stacks-block-height,
            completed-at: none,
            payment-status: "pending",
            total-cost: total-cost,
            platform-fee: platform-fee,
            provider-payment: provider-payment,
        })

        (var-set next-service-id (+ service-id u1))
        (ok service-id)
    )
)

(define-public (deposit-payment (service-id uint))
    (let (
            (service-data (unwrap! (map-get? ambulance-services service-id)
                ERR_SERVICE_NOT_FOUND
            ))
            (payment-amount (get total-cost service-data))
        )
        (asserts! (is-eq tx-sender (get patient service-data)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get payment-status service-data) "pending")
            ERR_SERVICE_ALREADY_PAID
        )

        (try! (stx-transfer? payment-amount tx-sender (as-contract tx-sender)))

        (map-set service-payments service-id {
            amount-deposited: payment-amount,
            payment-released: false,
            refunded: false,
            deposited-at: stacks-block-height,
            released-at: none,
        })

        (map-set ambulance-services service-id
            (merge service-data { payment-status: "deposited" })
        )

        (ok true)
    )
)

(define-public (complete-service (service-id uint))
    (let ((service-data (unwrap! (map-get? ambulance-services service-id) ERR_SERVICE_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get provider service-data)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get payment-status service-data) "deposited")
            ERR_SERVICE_NOT_AUTHORIZED
        )
        (asserts! (is-none (get completed-at service-data))
            ERR_SERVICE_ALREADY_COMPLETED
        )

        (map-set ambulance-services service-id
            (merge service-data {
                completed-at: (some stacks-block-height),
                payment-status: "completed",
            })
        )

        (ok true)
    )
)

(define-public (release-payment (service-id uint))
    (let (
            (service-data (unwrap! (map-get? ambulance-services service-id)
                ERR_SERVICE_NOT_FOUND
            ))
            (payment-data (unwrap! (map-get? service-payments service-id) ERR_SERVICE_NOT_FOUND))
            (provider-payment (get provider-payment service-data))
            (platform-fee (get platform-fee service-data))
        )
        (asserts! (is-eq tx-sender (get patient service-data)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get payment-status service-data) "completed")
            ERR_SERVICE_NOT_AUTHORIZED
        )
        (asserts! (not (get payment-released payment-data))
            ERR_SERVICE_ALREADY_PAID
        )

        (try! (as-contract (stx-transfer? provider-payment tx-sender (get provider service-data))))
        (try! (as-contract (stx-transfer? platform-fee tx-sender CONTRACT_OWNER)))

        (map-set service-payments service-id
            (merge payment-data {
                payment-released: true,
                released-at: (some stacks-block-height),
            })
        )

        (map-set ambulance-services service-id
            (merge service-data { payment-status: "paid" })
        )

        (let (
                (provider-data (unwrap!
                    (map-get? authorized-providers (get provider service-data))
                    ERR_INVALID_PROVIDER
                ))
                (patient-data (unwrap! (map-get? patient-profiles (get patient service-data))
                    ERR_INVALID_PATIENT
                ))
            )
            (map-set authorized-providers (get provider service-data)
                (merge provider-data { total-services: (+ (get total-services provider-data) u1) })
            )

            (map-set patient-profiles (get patient service-data)
                (merge patient-data {
                    total-services: (+ (get total-services patient-data) u1),
                    total-paid: (+ (get total-paid patient-data)
                        (get total-cost service-data)
                    ),
                })
            )
        )

        (ok true)
    )
)

(define-public (refund-payment (service-id uint))
    (let (
            (service-data (unwrap! (map-get? ambulance-services service-id)
                ERR_SERVICE_NOT_FOUND
            ))
            (payment-data (unwrap! (map-get? service-payments service-id) ERR_SERVICE_NOT_FOUND))
            (refund-amount (get amount-deposited payment-data))
            (time-limit (+ (get deposited-at payment-data) u144))
        )
        (asserts! (is-eq tx-sender (get patient service-data)) ERR_UNAUTHORIZED)
        (asserts! (not (get payment-released payment-data))
            ERR_REFUND_NOT_ALLOWED
        )
        (asserts! (not (get refunded payment-data)) ERR_REFUND_NOT_ALLOWED)
        (asserts!
            (or (is-none (get completed-at service-data)) (> stacks-block-height time-limit))
            ERR_REFUND_NOT_ALLOWED
        )

        (try! (as-contract (stx-transfer? refund-amount tx-sender (get patient service-data))))

        (map-set service-payments service-id
            (merge payment-data { refunded: true })
        )

        (map-set ambulance-services service-id
            (merge service-data { payment-status: "refunded" })
        )

        (ok true)
    )
)

(define-public (submit-review
        (service-id uint)
        (rating uint)
        (review (string-ascii 500))
    )
    (let ((service-data (unwrap! (map-get? ambulance-services service-id) ERR_SERVICE_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get patient service-data)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get payment-status service-data) "paid")
            ERR_SERVICE_NOT_AUTHORIZED
        )
        (asserts! (and (>= rating u1) (<= rating u10)) ERR_INVALID_SERVICE)

        (map-set service-reviews service-id {
            rating: rating,
            review: review,
            reviewed-at: stacks-block-height,
        })

        (let (
                (provider-data (unwrap!
                    (map-get? authorized-providers (get provider service-data))
                    ERR_INVALID_PROVIDER
                ))
                (current-rating (get rating provider-data))
                (total-services (get total-services provider-data))
                (new-rating (/ (+ (* current-rating total-services) rating)
                    (+ total-services u1)
                ))
            )
            (map-set authorized-providers (get provider service-data)
                (merge provider-data { rating: new-rating })
            )
        )

        (ok true)
    )
)

(define-public (update-platform-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (<= new-fee u20) ERR_INVALID_SERVICE)
        (var-set platform-fee-percentage new-fee)
        (ok true)
    )
)

(define-read-only (get-service (service-id uint))
    (map-get? ambulance-services service-id)
)

(define-read-only (get-provider (provider principal))
    (map-get? authorized-providers provider)
)

(define-read-only (get-patient (patient principal))
    (map-get? patient-profiles patient)
)

(define-read-only (get-payment-info (service-id uint))
    (map-get? service-payments service-id)
)

(define-read-only (get-service-review (service-id uint))
    (map-get? service-reviews service-id)
)

(define-read-only (get-platform-fee)
    (var-get platform-fee-percentage)
)

(define-read-only (get-next-service-id)
    (var-get next-service-id)
)

(define-read-only (calculate-service-cost
        (distance-km uint)
        (emergency-level uint)
    )
    (let (
            (base-cost (* distance-km u1000))
            (emergency-surcharge (if (> emergency-level u5)
                (/ (* base-cost (var-get emergency-surcharge-percentage)) u100)
                u0
            ))
            (total-cost (+ base-cost emergency-surcharge))
            (platform-fee (/ (* total-cost (var-get platform-fee-percentage)) u100))
            (provider-payment (- total-cost platform-fee))
        )
        {
            base-cost: base-cost,
            emergency-surcharge: emergency-surcharge,
            total-cost: total-cost,
            platform-fee: platform-fee,
            provider-payment: provider-payment,
        }
    )
)
