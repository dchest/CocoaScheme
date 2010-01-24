;; Arc syntax immitation, just for fun

(defmacro mac (name . body)
  `(defmacro ,name ,@body))

(mac = (name . body)
  `(define ,name ,@body))
  ; todo: '=' should be universal setter

(mac def (name args . body)
  `(define (,name ,@args) ,@body))

(def uniq () (gensym))

;; Macros

(mac class (name)
  `(string->objc:class (symbol->string ',name)))

;; Helpers

(def @ (x) (string->objc:string x))

(def str (x)
  (cond ((string? x) x)
        ((symbol? x) (symbol->string x))
        ((objc:id? x)
          (if (eqv? 1 (x is-kind-of-class: (class NSString))) ; doesn't work yet, need
            (objc:string->string x)                        ; to return BOOL values
            (objc:string->string (x 'description)))) ))    ; from selectors;
                                                           ; always returns description
;; Test App

(= file-manager
  ((class NSFileManager) 'default-manager))

(= current-directory-path
  (file-manager 'current-directory-path))

(def go (n)
  (let ((manager file-manager))
    (current-directory-path)
    (manager display-name-at-path: (@ "/Applications")))
    (if (> n 0)
      (go (- n 1))))

(go 20000)
(display (str current-directory-path))

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
