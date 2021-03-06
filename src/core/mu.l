;;;
;;;    SPDX-License-Identifier: MIT
;;;    Copyright (c) 2017-2021 James M. Putnam <putnamjm.design@gmail.com>
;;;

;;;
;;; mu forms
;;;
(:defsym mu::version "0.0.22")

(:defsym identity (:lambda (form) form))

;;; lists
(:defsym null (:lambda (t) (eq :nil t)))

(:defsym list (:lambda (:rest args) args))

(:defsym listp (:lambda (ptr)
  ((consp ptr) :t (null ptr))))

(:defsym atom (:lambda (form)
  (null (listp form))))

(:defsym list* (:lambda (:rest args)
  ((null (cdr args))
   (car args)
   (cons (car args) (apply list* (cdr args))))))

;;; progn/let/let*/letf/letf*/macrolet
(:defsym progn (:macro (:rest body)
  (list (list* :lambda () body))))

(:defsym let (:macro (bindl :rest body)
  (list*
    (list* :lambda (mapcar car bindl) body)
    (list* (mapcar (:lambda (vl) (nth 1 vl)) bindl)))))

(:defsym macrolet (:macro (bindl :rest body)
   (list*
     (list* :macro (mapcar car bindl) body)
       (list* (mapcar (:lambda (vl) (nth 1 vl)) bindl)))))

;;; letf - recursive serial lexical functions
(:defsym letf (:macro (bindl :rest body)
  (list* 'let
    (mapcar
     (:lambda (phrase)
        (list (car phrase) (list* 'recur phrase)))
      bindl)
    body)))

;;; letf* - recursive parallel lexical functions
(:defsym letf* (:macro (bindings :rest body)
  (list* 'let*
    (mapcar
     (:lambda (phrase)
        (list (car phrase) (list* 'recur phrase)))
      bindings)
    body)))

;;; block/return macros
(:defsym mu:block (:macro (tag :rest body)
  (list 'mu::block tag (list* :lambda () body))))

(:defsym mu:return-from (:macro (tag value)
  (list 'mu::return tag value)))

(:defsym mu:return (:macro (value)
  (list 'mu::return :nil value)))

;;; conditional
(:defsym if (:macro (test t f)
  (list (list 'null test) f t)))

;;; when/unless macros
(:defsym when (:macro (test :rest forms)
  (list (list 'null test) :nil (list* 'progn forms))))

(:defsym unless (:macro (test :rest forms)
  (list (list 'null test) (list* 'progn forms) :nil)))

;;; gensym
;;; think: this requires mutable lexicals
(:defsym gensym
   (let ((gensym-counter 0))
     #'(:lambda ()
          (let ((name (open-output-string "")))
            (:letq gensym-counter (fixnum+ 1 gensym-counter))
            (print "GENSYM-" name :nil)
            (print gensym-counter name :nil)
            (make-symbol (get-output-stream-string name))))))

;;; lexical bindings
;;; think: this requires mutable lexicals
(:defsym recur (:macro (fn lambda :rest body)
  (if (symbolp fn)
    (if (listp lambda)
      (let ((g (gensym)))
        (list 'let                            
          (list (list g (list :lambda (list fn)
            (list 'closure
              (list :letq fn (list* :lambda lambda body))))))
          (list g :nil)))
        (raise "is not a list (recur)" lambda))
    (raise "is not a symbol (recur)" fn))))

;;; let*
(:defsym let* (:macro (bindings :rest body)
   (letf ((bindfn (bindings body)
           (if (cdr bindings)
             (list 'let (list (car bindings)) (bindfn (cdr bindings) body))
             (list* 'let (list (car bindings)) body))))
     (bindfn bindings body))))

;;; and/or
(:defsym and (:macro (:rest forms)
  (letf ((andf (forms)
           (if (cdr forms)
             (list 'if (car forms) (andf (cdr forms)) ())
             (car forms))))
    (if forms (andf forms) :t))))

(:defsym or (:macro (:rest forms)
   (let ((value (gensym)))
     (letf ((orf (forms)
              (if (null (cdr forms))
                 (car forms)
                 (list 'let (list (list value (car forms)))
                   (list 'mu:if value value (orf (cdr forms)))))))
       (if forms (orf forms) ())))))

;;; cond
(:defsym cond (:macro (:rest forms)
  (letf ((clauses (forms)
           (and forms
             (let ((clause (car forms))
                   (result (gensym)))
               (if (consp clause)
                 (if (cdr clause)
                        (list 'if (car clause)
                              (list* 'progn (cdr clause))
                              (clauses (cdr forms)))
                        (list 'let (list (list result (car clause)))
                              (list 'if result result (clauses (cdr forms)))))
                 (raise "illegal clause (cond)" forms))))))
        (and forms (clauses forms)))))

;;; foldl/foldr
(:defsym foldl (:lambda (fold-fn fold-init fold-list)
  (letf ((fold (acc listf)
           (if (null listf)
             acc
             (fold (fold-fn acc (car listf)) (cdr listf)))))
    (fold fold-init fold-list))))

(:defsym foldr (:lambda (fold-fn fold-init fold-list)
   (letf ((fold (listf)
            (if (null listf)
              fold-init
              (fold-fn (car listf) (fold (cdr listf))))))
     (fold fold-list))))

;;; append
(:defsym append (:lambda (:rest lists)
  (mu:mapl
   (:lambda (l)
            (and (atom (car l)) (cdr l) (raise "is not a list" (car l))))
   lists)
  (foldr
    (:lambda (el acc)
       (if (listp el)
           (foldr (:lambda (el acc) (cons el acc)) acc el)
         el))
    ()
    lists)))

