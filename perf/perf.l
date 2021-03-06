;;; time macro
(defmacro perf-time (form)
  (let ((now (:lambda () (mu:vector-ref (mu::env-view) 3)))
        (now-usecs (gensym))
        (start-time (gensym))
        (start-room (gensym))
        (stop-time (gensym))
        (stop-room (gensym))
        (start-used (gensym))
        (stop-used (gensym))
        (result (gensym)))
    
    (list 'let* (list (list now-usecs (list now))
                      (list start-room (list 'mu::heap-view :t))
                      (list start-time (list now))
                      (list result form)
                      (list stop-time (list now))
                      (list stop-room (list 'mu::heap-view :t))
                      (list start-used
                            (list 'fixnum- (list 'mu:vector-ref start-room 1)
                                           (list 'mu:vector-ref start-room 3)))
                      (list stop-used
                            (list 'fixnum- (list 'mu:vector-ref stop-room 1)
                                           (list 'mu:vector-ref stop-room 3))))

          (list 'cons (list 'fixnum- stop-time start-time) (list 'fixnum- stop-used start-used)))))

;;; report
(defun perf-report (log)
  (let* ((functions '("mu:foldl"
                      "mu:foldr"
                      "mu:mapcar"
                      "mu:mapc"
                      "core.schar"
                      "core.stringp"
                      "core.string="
                      "core.vector"
                      "core.vector-to-list"))
         (rep (:lambda (log which)
           (let ((log-temp (fmt :nil "~A.tmp" log)))
             (mu::system (fmt :nil "echo \"(\" > ~A" log-temp))
             (if (null which)
                 (mu::system (fmt :nil "cat ~A >> ~A" log log-temp))
               (mu::system (fmt :nil "grep ~A ~A >> ~A" which log log-temp)))
             (mu::system (fmt :nil "echo \")\" >> ~A" log-temp))
  
             (let* ((logf (open-input-file log-temp))
                    (times (read logf))
                    (ntimes (mu:length times))
                    (sums
                     (mu:foldl
                      (:lambda (acc el)
                               (cons (fixnum+ (car el) (car acc))
                                     (fixnum+ (cdr el) (cdr acc))))
                      (cons 0 0)
                      times)))
               (close logf)
               (mu::system (fmt :nil "rm ~A" log-temp))
               (cons
                (car (truncate (car sums) 2500))
                (car (truncate (cdr sums) 2500)))))))
         (stat (:lambda (which)
           (let*
               ((stats (rep log which))
                (nused (car stats))
                (secs (cdr stats)))
             (fmt :t "~A: ~A ~A~%" which nused secs)))))
    (mu:mapc (:lambda (fn) (stat fn)) functions))
    ())
