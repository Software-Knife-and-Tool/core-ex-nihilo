;;;
;;;    SPDX-License-Identifier: MIT
;;;    Copyright (c) 2017-2021 James M. Putnam <putnamjm.design@gmail.com>
;;;

;;;
;;; core forms
;;;
(in-ns (ns "core" (list (find-ns "mu"))))

(:defsym core::version "0.0.2")

;;; assq/pairlis/acons
(:defsym  assq (:lambda (item alist)
  (unless (listp alist) (raise "is not a list (assq)" alist))
  (mu:block :nil
     (mu:mapc (:lambda (pair)
       (when (eq item (car pair)) (mu:return (cdr pair))))
       alist)
     :nil)))

(:defsym pairlis (:lambda (keys data)
  (unless (listp keys) (raise "is not a list (pairlis)" keys))
  (unless (listp data) (raise "is not a list (pairlis)" data))
  (unless (eq (mu:length keys) (mu:length data))
    (raise "unequal lengths (pairlis)" :nil))
  (letf ((zip (l1 l2)
              (if (or (null l1) (null l2))
                  ()
                (cons (cons (car l1) (car l2))
                      (zip (cdr l1) (cdr l2))))))
    (zip keys data))))

(:defsym acons (:lambda (key datum alist)
  (unless (listp alist) (raise "is not a list (acons)" alist))
  (cons (cons key datum) alist)))

;;; last
(:defsym last (:lambda (list n)
  (unless (listp list) (raise "is not a list (last)" list))
  (unless (fixnump n) (raise "is not a fixnum (last)" n))
  (when (fixnum< n 0) (raise "is not a positive fixnum (last)" n))
  (cond
   ((null list) ())
   ((eq 0 n) ())
   (:t
    (block :nil
      (letf ((last (n l)
        (cond
         ((eq n (mu:length list)) (return l))
         (:t (last (fixnum+ n 1) (cdr l))))))
        (last (fixnum- (fixnum- (mu:length list) n) 1) list)))))))

;;; butlast
(:defsym butlast (:lambda (list n)
  (unless (listp list) (raise "is not a list (butlast)" list))
  (unless (fixnump n) (raise "is not a fixnum (butlast)" n))
  (when (fixnum< n 0) (raise "is not a positive fixnum (butlast)" n))
  (cond
   ((null list) ())
   ((eq 0 n) list)
   (:t
    (block :nil
      (letf ((last (n l ll)
        (cond
         ((eq n (mu:length list)) (return (foldl (:lambda (x r) (cons r x)) () ll)))
         (:t (last (fixnum+ n 1) (cdr l) (cons (car l) ll))))))
        (last (fixnum- (fixnum- (mu:length list) n) 2) list ())))))))

;;; quasiquote
(set-macro-character #\`
  (:lambda (stream ch)
    (let ((parse-quasi (:lambda (quote-form)
      (letf ((quasi-list (form)
           (cond
            ((null form) form)
            ((and (consp form) (eq :unquote (car form)))
             (list 'list (nth 1 form)))
            ((and (consp form) (eq :splice (car form)))
             (nth 1 form))
            ((and (consp form) (eq :quasi (car form)) (atom (nth 1 form)))
             (nth 1 form))
            ((and (consp form) (eq :quasi (car form)) (consp (nth 1 form)))
             (list* 'append (mu:mapcar quasi-list (nth 1 form))))
            ((and (vectorp form) (eq :t (vector-type form))) (raise "implement bq vectors" form))
            (:t (list 'list (list :quote form))))))

         (let ((form (nth 1 quote-form)))
           (cond
            ((or (null form) (atom form)) form)
            ((and (consp form) (eq :unquote (car form))) (nth 1 form))
            ((and (consp form) (eq :splice (car form)) (nth 1 form))) ;;; undefined consequences
            ((and (consp form) (eq :quasi (car form)) (atom (nth 1 form))) (nth 1 form))
            ((and (vectorp form) (eq :t (vector-type form))) (raise "implement bq vectors" form))
            ((consp form) (quasi-list quote-form))
            (:t (raise "quasiquote botch" form))))))))
         (parse-quasi (list :quasi (read stream))))))

(set-macro-character #\,
  (:lambda (stream ch)                            
    (let ((ch (read-char stream)))
      (cond
       ((eq ch #\@) (list :splice (read stream)))
       (:t (unread-char ch stream) (list :unquote (read stream)))))))

;;; lambda
(:defsym core::parse-lambda (:lambda (lambda-list)
  (unless (listp lambda-list) (raise "lambda list is not a list" lambda-list))
  (letf* ((inits (llist)
           (let ((terms ()))
             (mu:block ()
               (mu:mapl
                (:lambda (l)
                  (let ((term (car l)) (rest (cdr l)))
                    (when (keywordp term) (mu:return (cons terms l)))
                    (unless (or (consp term) (symbolp term))
                      (raise "is not an opt symbol or initializer (lambda)" term))
                    (cond
                     ((consp term)
                      (unless (eq 2 (mu:length term))
                        (raise "is not a legal term (lambda)" term))
                      (let ((sym (nth 0 term)) (value (nth 1 term)))
                        (unless (and (symbolp sym) (null (keywordp sym)))
                          (raise "is not a legal term (lambda)" term))
                        (:letq terms (append terms (list term)))))
                     ((symbolp term)
                      (when (keywordp term)
                        (raise "is not a legal term (lambda)" term))
                      (:letq terms (append terms (list (list term ()))))))))
                llist)
               (cons terms ()))))
          (reqs (llist)
            (mu:block ()
             (let ((required ()))
               (mu:mapl
                (:lambda (l)
                  (let ((sym (car l)) (rest (cdr l)))
                     (when (keywordp sym) (mu:return (cons required l)))
                     (unless (symbolp sym) (raise "is not a symbol (lambda)" sym))
                     (:letq required (append required (list sym)))))
                llist)

               (cons required ()))))
          (opts (llist)
            (cond
             ((or (null (eq (car llist) :option)) (null llist)) (cons () llist))
             (:t (inits (cdr llist)))))
          (keys (llist)
            (cond
             ((or (null (eq (car llist) :key)) (null llist)) (cons () llist))
             (:t (inits (cdr llist)))))
          (rest (llist)
            (cond
              ((or (null (eq (car llist) :rest)) (null llist)) (cons () llist))
              (:t (unless (eq 2 (mu:length llist))
                    (raise "excess elements (lambda)" llist))
                  (let ((sym (nth 1 llist)))
                    (unless (and (symbolp sym) (null (keywordp sym)))
                      (raise "illegal rest clause (lambda)" llist))
                    (cons sym (nthcdr 2 llist)))))))

         (let* ((requireds (reqs lambda-list))
                (optionals (opts (cdr requireds)))
                (keywords (keys (cdr optionals)))
                (rest (rest (cdr keywords))))
           (list (car requireds) (car optionals) (car keywords) (car rest))))))

;;; defun/defconstant/defmacro/lambda/letrec (now with added recursion)
(:defsym defun (:macro (fn lambda :rest body)
  (unless (symbolp fn) (raise "is not a symbol (defun)" fn))
  (unless (listp lambda) (raise "is not a list (defun)" lambda))
  (list :defsym fn (list* 'recur fn lambda body))))

(:defsym defconstant (:macro (name form)
  (unless (symbolp name) (raise "is not a symbol (defun)" name))
  (list :defsym name form)))

(:defsym defmacro (:macro (name lambda :rest body)
  (unless (symbolp name) (raise "is not a symbol (defun)" name))
  (unless (listp lambda) (raise "is not a list (defun)" lambda))
  (list :defsym name (list* :macro lambda body))))

(:defsym letrec (:macro (bindl :rest body)
  (let ((names (mu:mapcar
                 (:lambda (phrase)
                   (nth 0 phrase))
                 bindl))
        (letqs (mu:mapcar
                 (:lambda (phrase)
                   (list :letq
                         (nth 0 phrase)             
                         (list* :lambda (nth 1 phrase) (nthcdr 2 phrase))))
                   bindl))
        (closures (mu:mapcar
                    (:lambda (phrase)
                      (list :letq
                        (nth 0 phrase)
                        (list 'closure (nth 0 phrase))))
                    bindl))
        (args (mu:mapcar (:lambda (phrase)) bindl)))

    (list 'mu:apply
          (list* :lambda names (append letqs closures body))
          (list :quote args)))))

;;; strings accessor
(defun schar (string index)
  (mu:vector-ref string index))

;;; stringp - string predicate
(defun stringp (object)
  (and (vectorp object) (eq (mu:vector-type object) :char)))

;;; string - string coercion
(defun string (object)
  (cond
   ((stringp object) object)
   ;;; x((charp object) #(:char object))
   ((symbolp object) (symbol-name object))
   (:t (raise "illegal conversion (string)" object))))

;;; string= - string comparison
(defun string= (str1 str2)
  (unless (stringp str1) (raise "is not a string (string=)" str1))
  (unless (stringp str2) (raise "is not a string (string=)" str2))
  (when (eq (mu:vector-length str1) (mu:vector-length str2))
    (let ((nth 0) (len (mu:vector-length str1)))
      (letf ((inc ()
        (cond
         ((eq nth len) :t)
         ((eq (mu:vector-ref str1 nth) (mu:vector-ref str2 nth))
          (:letq nth (fixnum+ 1 nth))
          inc)
         (:t :nil))))
            (mu:trampoline inc)))))

;;; vector - coerce list to vector
(defun vector (type :rest list)
  (mu:list-to-vector type list))

;;; vector-to-list - make a list from vector
(defun vector-to-list (vector)
  (let ((lst :nil))
    (mu:vector-mapc
     (:lambda (el) (:letq lst (cons el lst)))
     vector)
    (foldl (:lambda (x r) (cons r x)) () lst)))

;;; float - coerce object to float
(defun float (object)
  (cond
   ((floatp object) object)
   ((fixnump object)
    (let ((out (open-output-string "")
          (print object out :nil)
          (print ".0" out :nil)))
      (read (open-input-string (get-output-stream-string out)))))
   (:t (raise "cannot coerce (float)" object))))

;;; fmt dest string args...
(defun fmt (stream fmt-string :rest args)
  (unless (stringp fmt-string) (raise "format is not a string" fmt-string))
  (let* ((dest
          (cond
           ((null stream) (open-output-string ""))
           ((eq stream :t) :nil)
           ((streamp stream) stream)
           (:t (raise "destination is not :t, :nil or a stream (fmt)" stream))))
         (fmt (open-input-string fmt-string))
         (radix-string (:lambda (radix fix)
           (let ((out (open-output-string ""))
                 (digits "0123456789abcdef"))
             (letf ((radixf (fx)
                            (cond
                             ((eq fx 0) :nil)
                             (:t (radixf (car (truncate fx radix)))
                                 (write-char (mu:vector-ref digits
                                                            (logand fx (fixnum- radix 1)))
                                             out)))))
                   (if (eq fix 0)
                       "0"
                     (progn (radixf fix)
                            (get-output-stream-string out))))))))

    (letf ((loop (args)
             (let ((ch (read-char fmt)))
               (cond
                ((null ch)
                 (if stream
                     dest
                   (get-output-stream-string dest)))
                ((eq ch #\~)
                 (let ((dir (read-char fmt)))
                   (cond
                    ((null dir) (raise "eof while processing directive" :nil) :nil)
                    ((eq dir #\~) (write-char #\~ dest) (loop args))
                    ((eq dir #\%) (terpri dest) (loop args))
                    (:t (cond
                         ((eq dir #\A) (mu:print (car args) dest :nil))
                         ((eq dir #\C) (mu:print (car args) dest :nil))
                         ((eq dir #\S) (mu:print (car args) dest :t))
                         ((eq dir #\X) (let ((fix (car args)))
                                         (unless (fixnump fix) (raise "is not a fixnum (fmt)" fix))
                                         (mu:print (radix-string 16 fix) dest :nil)))
                         ((eq dir #\D) (let ((fix (car args)))
                                         (unless (fixnump fix) (raise "is not a fixnum (fmt)" fix))
                                         (mu:print (radix-string 10 fix) dest :nil)))
                         ((eq dir #\O) (let ((fix (car args)))
                                         (unless (fixnump fix) (raise "is not a fixnum (fmt)" fix))
                                         (mu:print (radix-string 8 fix) dest :nil)))
                         ((eq dir #\W) (mu:print (car args) dest :t)))
                        (loop (cdr args))))))
                (:t (write-char ch dest) (loop args))))))
          (loop args))))

;;; room
(defun room (:rest args)
  (unless (fixnum< (mu:length args) 2) (raise "one optional argument (room)" args))
  (let* ((opt (car args))
         (type-info (mu::heap-view :t))
         (size (mu:vector-ref type-info 0))
         (nbytes (mu:vector-ref type-info 1))
         (nalloc (mu:vector-ref type-info 2))
         (nfree (mu:vector-ref type-info 3)))
    
    (cond
     ((or (null args) (eq :default opt)) :t)
     ((eq opt :t)
        (mu:mapc
          (:lambda (type)
             (let*
                 ((type-info (mu::heap-view type))
                  (size (mu:vector-ref type-info 0))
                  (nbytes (mu:vector-ref type-info 1))
                  (nalloc (mu:vector-ref type-info 2))
                  (nfree (mu:vector-ref type-info 3)))
               (unless (eq nbytes 0)
                 (fmt :t "~A (object size: ~A), bytes used ~A, objects allocated ~A, bytes free ~A~%"
                      type size nbytes nalloc nfree))))
          '(:t :cons :condtn :func :macro :namespc :stream :string :struct :symbol :vector)))
     ((null opt)
      (fmt :t "heap: bytes used ~A, objects allocated ~A, bytes free ~A~%"
           nbytes nalloc nfree))
     (:t (raise "unknown argument (room)" opt)))
    (fixnum+ (fixnum- size nbytes) nfree)))

;;; time macro
(defmacro time (form)
  (let ((now (:lambda ()
         (let* ((now (mu::clocks))
           (sec (float (nth 0 now)))
           (usec (float/ (float (nth 1 now)) 1000000.0)))
           (float+ sec usec))))
        (now-secs (gensym))
        (start-time (gensym))
        (start-room (gensym))
        (stop-time (gensym))
        (stop-room (gensym))
        (start-used (gensym))
        (stop-used (gensym))
        (result (gensym)))
    
    (list 'let* (list (list now-secs now)
                      (list start-room (list 'mu::heap-view :t))
                      (list start-time (list now-secs))
                      (list result form)
                      (list stop-time (list now-secs))
                      (list stop-room (list 'mu::heap-view :t))
                      (list start-used
                            (list 'fixnum- (list 'mu:vector-ref start-room 1)
                                           (list 'mu:vector-ref start-room 3)))
                      (list stop-used
                            (list 'fixnum- (list 'mu:vector-ref stop-room 1)
                                           (list 'mu:vector-ref stop-room 3))))
          (list 'fmt :t "Evaluation:~%")
          (list 'fmt :t "  ~A seconds of real time~%" (list 'float- stop-time start-time))
          (list 'fmt :t "  ~A bytes consed~%" (list 'fixnum- stop-used start-used))
          result)))

;;; typecase
(defmacro typecase (keyform :rest type-clauses)
  (let ((typesym (gensym)))
    (list* (list 'let (list (list typesym (list 'type-of keyform)))
      (list* 'cond 
             (mu:mapcar
              (:lambda (clause)
                (if (consp clause)
                  (list* (list 'eq (car clause) typesym) (cdr clause))
                  (raise "illegal clause (typecase)" forms)))
              type-clauses))))))

;;; defstruct: immutable objects
(defmacro defstruct (struct-name :rest struct-slot-defs)
  (unless (symbolp struct-name) (raise "is not a string (defstruct)" struct-name))
  (let* ((slot-def-alist
          ;; parse slot definitions and make an alist from them
          ;; (slot-name init-value type)
          (foldl
           (:lambda (acc def)
              (unless (listp def) (raise "slot definition is not a list (defstruct)" def))
              (unless (eq (mu:length def) 3) (raise "malformed slot definition (defstruct)" def))
              (unless (symbolp (nth 0 def)) (raise "slot name is not a symbol (defstruct)" (nth 0 def)))
              (unless (keywordp (nth 2 def)) (raise "slot type is not a keyword (defstruct)" (nth 2 def)))
              (acons (nth 0 def) (cdr def) acc))
            ()
            struct-slot-defs))

         ;; struct constructor function definition
         ;; (:defsym make-{struct-name} (struct :{struct-name} (slot-values values-list)))
         (constructor
           (let ((slot-values #'(:lambda (values) ;; function that returns a slot value alist
                   ;; values '(slot-name slot-value ...)
                   ;; if slot-name is in the values list, bind it to eval'd slot-value
                   ;; if not, bind it to eval'd init value from slot-def-alist
                   (when (logand (mu:length values) 1)
                     (raise "ill-formed struct initializer (defstruct)" values))
                   (let ((values-alist
                           (foldl
                             (:lambda (acc acons) (if (null acons) acc (cons acons acc)))
                             ()
                             (mu:maplist
                              (:lambda (cdr)
                                (when (eq (logand 1 (mu:length cdr)) 0) (cons (nth 0 cdr) (nth 1 cdr))))
                              values))))
                     (mu:mapcar
                      (:lambda (def)
                        (let ((value (assq (car def) values-alist)))
                          (cons (car def) (eval (if (null value) (nth 0 (cdr def)) value)))))
                      slot-def-alist)))))
                (list :defsym (read (open-input-string (fmt :nil "make-~A" (symbol-name struct-name))))
                  (list :macro (list :rest 'inits)
                    (list 'struct (keyword (symbol-name struct-name)) (list slot-values 'inits))))))

         ;; struct predicate function definition
         ;; (:defsym {struct-name}p (closure (:lambda (struct) (eq (struct-type struct) :{struct-name}))))
         (predicate
          (list :defsym (read (open-input-string (fmt :nil "~Ap" struct-name)))
                (list 'closure (list :lambda
                      (list 'st)
                      (list 'eq (list 'struct-type 'st)
                            (list 'keyword (list symbol-name struct-name)))))))

         ;; list of reader function definitions
         ;; (:defsym {struct-name}-{slot-name}
         ;;   (closure (:lambda (struct) (assq {struct-name} (struct-values struct)) ...)))
         (readers
           (mu:mapcar
             (:lambda (def)      
               (list :defsym
                 (read (open-input-string (fmt :nil "~A-~A" struct-name (car def))))
                 (list 'closure (list :lambda
                   (list 'st)
                   (list 'assq
                     (list :quote (car def))
                     (list 'struct-slots 'st))))))
             slot-def-alist)))

    (eval (list* 'progn constructor predicate readers))
    (list :quote struct-name)))

;;; with-ns - lexical namespacing
(defmacro with-ns (ns-arg :rest body)
  (let ((ns (eval ns-arg)))
    (unless (namespacep ns) (raise "is not a namespace (with-ns)" ns-arg))
    (let* ((body-stream (open-output-string ""))
           (body-vstream (open-output-string ""))
           (body-string
            (progn (mu:print body body-stream :t)
                   (mu:print (vector-to-list (get-output-stream-string body-stream)) body-vstream :t)
                   (read (open-input-string (get-output-stream-string body-vstream))))))
      (list 'let (list (list '%namespace% ns))
            (list 'mu:mapc 'eval
                  (list 'read (list 'open-input-string
                                    (list 'mu:list-to-vector :char (list :quote body-string)))))))))

;;; while bouncing on a trampoline
(defmacro while (test :rest body)
  (list 'letf (list (list 'whilef ()
    (list 'when test (list (list* :lambda () body)) 'whilef)))
      (list 'mu:trampoline 'whilef)))

;;; require/provide macro
(:defsym require (:macro (tag path)
  (let ((string-concat (:lambda (:rest strings)
    (let ((ostream (open-output-string "")))
      (mu:mapc (:lambda (str) (mu:print str ostream :nil)) strings)
      (get-output-stream-string ostream)))))

   ;;; (fmt :t "require: tag ~A path ~A~%" tag path)
   (unless (boundp 'lib-base) (raise "require: lib-base is not bound" :nil))
   (unless (symbolp tag) (raise "require: tag is not a symbol" tag))
   (unless (stringp path) (raise "require: path is not a string" path))
   (unless (boundp tag)
     (let ((load-verbose (when (boundp 'load-verbose) load-verbose)))
       (when load-verbose (fmt :t "require: loading ~A~%" path))
       (list 'progn (list :defsym tag :nil)
          (list 'load (string-concat lib-base path))))))))
