;; Helpers

(define (@ x) (string->objc:string x))
(define (@@ x) (objc:string->string x))

;; Macros

(defmacro = (name value)
  `(define ,name ,value))

(defmacro class (name)
  `(string->objc:class (symbol->string ',name)))


;; Test App

(= file-manager
  ((class NSFileManager) 'default-manager))

(= current-directory-path
  (file-manager 'current-directory-path))

(define (go n)
  (let ((manager file-manager))
    (current-directory-path)
    (manager display-name-at-path: (@ "/Applications")))
    (if (> n 0)
      (go (- n 1))))

(go 100)
(display (@@ (file-manager 'current-directory-path)))

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
