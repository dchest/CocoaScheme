;; Macros

(defmacro = (name value)
  `(define ,name ,value))

(defmacro class (name)
  `(string->objc:class (symbol->string ',name)))

;; Helpers

(define (@ x) (string->objc:string x))

(define (str x)
  (cond ((string? x) x)
        ((symbol? x) (symbol->string x))
        ((objc:id? x)
          (if (eqv? 1 (x isKindOfClass: (class NSString))) ; doesn't work yet, need
            (objc:string->string x)                        ; to return BOOL values
            (objc:string->string (x 'description)))) ))    ; from selectors;
                                                           ; always returns description
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
(display (str (file-manager 'current-directory-path)))

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
