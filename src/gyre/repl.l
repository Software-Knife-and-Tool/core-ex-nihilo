;;;
;;; repl.l
;;;

;;; repl stdin
(defun repl ()
  (fmt :t "gyre repl (:? for help)~%")
  (fmt :t "versions:~%")
  (fmt :t "  mu      : ~A~%" mu::version)
  (fmt :t "  core    : ~A~%" core::version)
  (fmt :t "  gyre    : ~A~%" gyre::version)
  (fmt :t "  common  : ~A~%" common::version)
  (fmt :t "  compiler: ~A~%" compiler::version)
  (fmt :t "heap:~%")
  (fmt :t "  bytes free: ~A~%~%" (gc :t))
  (let* ((history (open-output-string ""))
         (history-list
          (:lambda ()
            (let ((ostr (open-output-string ""))
                  (hstr (get-output-stream-string history)))
              (fmt ostr "(~A)" hstr)
              (fmt history "~A" hstr)
              (mu:read (open-input-string (get-output-stream-string ostr))))))
         (add-history (:lambda (form) (fmt history "~A " form)))
         (print-history
          (:lambda ()
            (let* ((hist (history-list))
                   (len (length hist)))    
              (mu:mapl
               (:lambda (expr)                      
                        (fmt :t ":~A ~A~%"
                             (1- (fixnum- len (length (cdr expr))))
                             (car expr)))
               (history-list))))))

    (block :nil
      (while (null (eofp :t))
        (let ((sexpr (progn (fmt :t "~A> " (ns-name (current-ns))) (mu:read :t))))
          (cond
           ((eq sexpr :?) (fmt :t ":? - this message~%")
            (fmt :t ":h - print history stack~%")
            (fmt :t ":n - eval nth history entry~%"))
           ((eq sexpr :h) (print-history))
           ((eq sexpr :r) (fmt :t "~A~%" (get-output-stream-string results)))
           ((and (keywordp sexpr) (fixnump (read-from-string (symbol-name sexpr))))
            (let* ((n (read-from-string (symbol-name sexpr)))
                   (hist (history-list))
                   (len (length hist)))
              (when (fixnum< n len)
                (fmt :t "~A~%" (eval (nth n hist)) :t))))
           ((eq sexpr :q) (return :t))
           (:t (with-condition
                (:lambda ()
                         (add-history sexpr)
                         (fmt :t "~A~%" (eval sexpr)))
                break))))))))
