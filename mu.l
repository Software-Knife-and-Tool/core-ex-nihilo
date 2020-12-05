(:defsym que (:macro (bindl :rest body)
   (let ((fnc (:lambda (fn bindl body)
           (mu:if (cdr bindl)
             (list 'let (list (car bindl)) (fn fn (cdr bindl) body))
             (list* 'let (list (car bindl)) body)))))
     (fnc fnc bindl body))))