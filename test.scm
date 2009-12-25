(display "Applications directory name: ")
(define file-manager ((alloc-objc:object (string->objc:class "NSFileManager")) "init"))
(define test-path (string->objc:string "/Applications"))
(display 
  (objc:string->string (file-manager "displayNameAtPath:" test-path)))
(newline)