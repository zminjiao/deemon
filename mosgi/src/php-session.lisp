#|
Author:Simon Koch <s9sikoch@stud.uni-saarland.de>
This file contains code to parse serialized php-sessions

As I got lazy thinking on how to represent the php session
as pure list/tree I go for an OOP approach:
http://c2.com/cgi/wiki?DesignForTheSakeOfDesign

:<TYPE-CHAR>:<SIZE-NUMBER>:<CONTENT>
-> :s:<SIZE>:"<STRING-CONTENT>"
-> :a:<SIZE>:{<ARRAY-CONTENT>}
|#

(in-package :de.uni-saarland.syssec.mosgi.php-session)


(defun get-hashtable-keys (table)
  (loop for key being the hash-keys of table
     collect key))


(define-condition php-text-serialized-session-parsing-condition (simple-condition)
  ())


(defclass php-session-content ()
  ((content-type
    :initarg :content-type
    :reader content-type)))


(defgeneric diff (old-element new-element)
  (:documentation "diff the two given elements"))


(defclass php-session-string-element (php-session-content)
  ((content
    :initarg :content
    :reader content)
   (content-type
    :initform :string)))


(defmethod print-object ((content-element php-session-string-element) stream)
  (with-slots (content-type content)
      content-element
    (FORMAT stream "(~a ~a)" content-type content)))


(defun parse-content-element-string (size char-list)
  (when (not (char= #\" (car char-list)))
    (error 'php-text-serialized-session-parsing-condition
	   :format-control "expected \" to start string content but encountered ~a in ~a"
	   :format-arguments (list (car char-list) char-list)))
  (let ((string-content-end (position #\" char-list :start 1 :test #'char=)))
    (if (or (not string-content-end)
	    (= string-content-end size))
	(error 'php-text-serialized-session-parsing-condition 
	       :format-control "expected string of length ~a but encountered end of list/bad size ~a"
	       :format-arguments (list size char-list))
	(values (make-instance 'php-session-string-element 
			       :content (coerce (subseq char-list 1 string-content-end) 'string))
		(subseq char-list (+ string-content-end 1))))))


(defclass php-session-array-element (php-session-content)
  ((elements 
    :initarg :elements
    :reader elements)
   (content-type
    :initform :array)))


(defmethod get-keys ((array-element php-session-array-element))
  (get-hashtable-keys (slot-value array-element 'elements)))


(defmethod get-element ((array-element php-session-array-element) key)
  (gethash key (slot-value array-element 'elements)))


(defmethod print-object ((content-element php-session-array-element) stream)
  (with-slots (content-type elements)
      content-element
    (FORMAT stream "( ~a (~{ ~a ~}))" 
	    content-type
	    (mapcar #'(lambda(key)
			(FORMAT nil "(:STRING . ~a ) => ~a" key (gethash key elements)))
		    (sort (get-hashtable-keys elements) #'string<=)))))


(defun array-content->hashtable (array-elements)
  (when (not (= (mod (length array-elements) 2) 0))
    (error 'php-text-serialized-session-parsing-condition
	   :format-control "uneven content of array - expected associative array?"))
  (do ((table (make-hash-table :test 'equalp))
       (remaining array-elements (cddr remaining)))
      ((not remaining) table)
    (when (not (eq (content-type (car remaining)) :string))
      (error 'php-text-serialized-session-parsing-condition
	     :format-control "expected 0 + (2*d - 1) element of array to be of type string not ~a in ~a"
	     :format-arguments (list (content-type (car remaining)) array-elements)))
    (setf (gethash (content (car remaining)) table)
	  (cadr remaining))))


(defun parse-content-element-array (size char-list)
  (when (not (char= #\{ (car char-list)))
    (error 'php-text-serialized-session-parsing-condition 
	   :format-control "expected { to start array content but encountered ~a in ~a"
	   :format-arguments (list (car char-list) char-list)))
  (do ((counter 0 (+ counter 1))
       (rem-char-list (cdr char-list))
       (elements nil))
      ((= counter (* 2 size))
       (values (make-instance 'php-session-array-element :elements (array-content->hashtable (reverse elements)))
	       (if (not (char= #\} (car rem-char-list)))
		   (error 'php-text-serialized-session-parsing-condition
			  :format-control "expected } to end array contetn but encountered ~a in ~a"
			  :format-arguments (list (car rem-char-list) rem-char-list))
		   (cdr rem-char-list))))
    (multiple-value-bind (element rem-chars)
	(parse-session-content-element rem-char-list)
      (push element elements)
      (setf rem-char-list rem-chars))))


(defclass php-session-element (php-session-content)
  ((name
    :initarg :name
    :reader name)
   (content
    :initarg :content
    :reader content)
   (type 
    :initform :element)))


(defmethod print-object ((element php-session-element) stream)
  (FORMAT stream "( ~a ~a )" (name element) (content element)))


(defun parse-session-content-element-head (char-list)
  (when (not (and (>= (count #\: char-list :test #'char=) 3)
		  (char= (car char-list) #\:)))
    (error 'php-text-serialized-session-parsing-condition
	   :format-control "malformed session element string at head ~a"
	   :format-arguments (list char-list)))
  (let* ((first-colon 0)
	 (second-colon (position #\: char-list :start (+ first-colon 1) :test #'char=))
	 (third-colon  (position #\: char-list :start (+ second-colon 1) :test #'char=)))
    (when (or (not (= (- second-colon first-colon) 2))
	      (not (> (- third-colon second-colon 1))))
      (error 'php-text-serialized-session-parsing-condition
	     :format-control "malformed session element content at head need exact 1 char for type and at least 1 char for size : ~a"
	     :format-arguments (list char-list)))
    (values (car (subseq char-list (+ first-colon 1) second-colon))
	    (parse-integer (coerce (subseq char-list (+ second-colon 1) third-colon) 'string))
	    (subseq char-list (+ third-colon 1)))))
	 

(defun parse-session-content-element (char-list)
  (multiple-value-bind (type size rest)
      (parse-session-content-element-head char-list)
    (ecase type
      (#\s
       (parse-content-element-string size rest))
      (#\a
       (parse-content-element-array size rest)))))
      

(defun parse-session-element (char-list element-name)
  (make-instance 'php-session-element
		 :name element-name
		 :content (parse-session-content-element char-list)))


(defclass php-session ()
  ((session-id
    :initarg :session-id
    :initform (error "parameter session-id has to be provided")
    :reader session-id)
   (elements 
    :initarg :elements
    :reader elements)))


(defmethod print-object ((session php-session) stream)
  (FORMAT stream "( ~a (~{ ~a ~}))" (session-id session) (elements session)))


(defun parse-php-session (stream session-id)
  (do ((line (read-line stream nil nil)
	     (read-line stream nil nil))
       (session-elements nil))
      ((not line) (make-instance 'php-session :elements (sort session-elements #'string<= :key #'name) :session-id session-id))
    (let ((char-list (coerce line 'list)))
      (when (not (find #\| char-list :test #'char=))
	(error 'php-text-serialized-session-parsing-condition
	       :format-arguments `(,line)
	       :format-control "session line does not contain expected | : ~a"))
      (push (parse-session-element (subseq char-list (+ (position #\| char-list :test #'char=) 1))
				   (coerce (subseq char-list 0 (position #\| char-list :test #'char=)) 'string))
	    session-elements))))


(defun create-empty-php-session (session-id)
  (make-instance 'php-session
		 :elements nil
		 :session-id session-id))
    
    

	  


