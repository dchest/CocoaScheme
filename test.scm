(define (@ x) (string->objc:string x))
(define (@@ x) (objc:string->string x))

(display
  (@@ (((string->objc:class "NSFileManager") 'default-manager) 'display-name-at-path: (@ "Applications"))))

(newline)

;--------------------
; GOAL, not implemented:
; ~~~~~~~~~~~~~~~~~~~~~
;(define-class "Something"
;  (define-var 'x)
;  (define-var 'y)
;  (- 'set-x v
;    (set-var! x v))
;  (- 'set-y v
;    (set-var! y v))
;  (- 'multiply
;    (* x y)))