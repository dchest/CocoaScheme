(display "Applications directory name: ")
;(define file-manager ((alloc-objc:object (string->objc:class "NSFileManager")) "init"))
;(define test-path (string->objc:string "/Applications"))
;(display 
;  (objc:string->string (file-manager "displayNameAtPath:" test-path)))
;(newline)
;--------------------
(display
  (objc:string->string 
    (((string->objc:class "NSFileManager") 'default-manager) 'display-name-at-path: (string->objc:string "Applications"))))
(newline)
;--------------------
;(define-class "Something"
;  (define-var 'x)
;  (define-var 'y)
;  (- 'set-x v
;    (set-var! x v))
;  (- 'set-y v
;    (set-var! y v))
;  (- 'multiply
;    (* x y)))