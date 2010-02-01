;; Arc syntax immitation, just for fun
;
;(defmacro mac (name . body)
;  `(defmacro ,name ,@body))
;
;(mac = (name . body)
;  `(define ,name ,@body))
;   todo: '=' should be universal setter
;
;(mac def (name args . body)
;  `(define (,name ,@args) ,@body))
;
;(def uniq () (gensym))
;
;; Macros

(defmacro class (name)
  `(string->objc:class (symbol->string ',name)))

;; Helpers

(define (only fn lst)
  "(only fn lst) returns list of all elements of lst that evaluate to #t when applied to fn"
  (if (null? lst)
      ()
      (if (fn (car lst))
          (cons (car lst) (only fn (cdr lst)))
          (only fn (cdr lst)))))

;; Test App

(define file-manager
  ((class NSFileManager) 'default-manager))

(define (current-directory-path)
  (file-manager 'current-directory-path))

(define (go n)
  (let ((manager file-manager))
    (current-directory-path)
    (manager display-name-at-path: "/Applications"))
    (if (> n 0)
      (go (- n 1))))

;(go 20000)
(display ((class NSNumber) number-with-integer: 42))
(newline)
(display (current-directory-path))
(newline)

(let ((klass (objc:allocate-class-pair "MyObject" (class NSObject))))
  (objc:add-method klass "testMe:" "d@:d")
  (objc:register-class-pair klass))

(define (objc:MyObject:testMe: self x)
  (display x)
  (newline)
  13.3)
  
;(((class NSGarbageCollector) 'default-collector) 'collect-exhaustively)

;(defclass MyObject
;  (- (double testMe: double)

;(define (objc:MySubObject:testMe)
;  (display "sub works too!\n"))

;(let ((klass (objc:allocate-class-pair "MySubObject" (class MyObject))))
;  (objc:add-method klass "testMe:" "v@:d")
;  (objc:register-class-pair klass))

(display ((((class MyObject) 'alloc) 'init) testMe: 14.2))

(objc:framework "Cocoa")
(display ((((class NSButton) 'alloc) init-with-frame: '(20.24 30 100 200)) 'frame))
;((((class MySubObject) 'alloc) 'init) unknownMethod: 10.4)

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
