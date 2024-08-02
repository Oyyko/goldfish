; 0-clause BSD
; Adapted from S7 Scheme's r7rs.scm

(define-macro (define-library libname . body) ; |(lib name)| -> environment
  `(define ,(symbol (object->string libname))
     (with-let (sublet (unlet)
                         (cons 'import import)
                         (cons '*export* ())
                         (cons 'export (define-macro (,(gensym) . names)
                                         `(set! *export* (append ',names *export*)))))
       ,@body
       (apply inlet
              (map (lambda (entry)
                     (if (or (member (car entry) '(*export* export import))
                             (and (pair? *export*)
                                  (not (member (car entry) *export*))))
                         (values)
                         entry))
                   (curlet))))))

(unless (defined? 'r7rs-import-library-filename)
  (define (r7rs-import-library-filename libs)
    (when (pair? libs)
      (let ((lib-filename (let loop ((lib (if (memq (caar libs) '(only except prefix rename))
                                              (cadar libs)
                                              (car libs)))
                                     (name ""))
                            (set! name (string-append name (symbol->string (car lib))))
                            (if (null? (cdr lib))
                                (string-append name ".scm")
                                (begin
                                  (set! name (string-append name "/"))
                                  (loop (cdr lib) name))))))
        (unless (member lib-filename (*s7* 'file-names))
          (load lib-filename)))
      (r7rs-import-library-filename (cdr libs)))))

(define-macro (import . libs)
  `(begin
     (r7rs-import-library-filename ',libs)
     (varlet (curlet)
       ,@(map (lambda (lib)
                (case (car lib)
                  ((only)
                   `((lambda (e names)
                       (apply inlet
                              (map (lambda (name)
                                     (cons name (e name)))
                                   names)))
                     (symbol->value (symbol (object->string (cadr ',lib))))
                     (cddr ',lib)))
                  ((except)
                   `((lambda (e names)
                       (apply inlet
                              (map (lambda (entry)
                                     (if (member (car entry) names)
                                         (values)
                                         entry))
                                   e)))
                     (symbol->value (symbol (object->string (cadr ',lib))))
                     (cddr ',lib)))
                  ((prefix)
                   `((lambda (e prefx)
                       (apply inlet
                              (map (lambda (entry)
                                     (cons (string->symbol 
                                            (string-append (symbol->string prefx) 
                                                           (symbol->string (car entry)))) 
                                           (cdr entry)))
                                   e)))
                     (symbol->value (symbol (object->string (cadr ',lib))))
                     (caddr ',lib)))
                  ((rename)
                   `((lambda (e names)
                       (apply inlet
                              (map (lambda (entry)
                                     (let ((info (assoc (car entry) names)))
                                       (if info
                                           (cons (cadr info) (cdr entry))
                                           entry))) 
                                   e)))
                     (symbol->value (symbol (object->string (cadr ',lib))))
                     (cddr ',lib)))
                  (else
                   `(let ((sym (symbol (object->string ',lib))))
                      (if (not (defined? sym))
                          (format () "~A not loaded~%" sym)
                          (symbol->value sym))))))
              libs))))