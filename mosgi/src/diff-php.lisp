#|
Author:Simon Koch <s9sikoch@stud.uni-saarland.de>
This file provides code to generate and diff php-session-history-states for
clustering of page requests
|#
(in-package :de.uni-saarland.syssec.mosgi.diff)


(defstruct php-session-diff-entry diffs)
	   

(defclass php-session-state (history-state)
  ((php-sessions
    :initarg :php-sessions
    :reader php-sessions)))


(defmethod print-object ((pss php-session-state) stream)
  (FORMAT stream "~{Session:~a~^~%~}" (php-sessions pss)))


(defmethod diff-history-state ((old php-session-state) (new php-session-state))
  (labels ((php-sessions-diff (old-sessions new-sessions) ;assumes string<= ordered indexes - true by definition of file-history-state
	     (FORMAT T "~a/~a~%" (type-of (car old-sessions)) (type-of (car new-sessions)))
	     (cond 
	       ((not old-sessions)
		(mapcar #'(lambda (session) (cons session :ADDED)) new-sessions))
	       ((not new-sessions)
		(mapcar #'(lambda (session) (cons session :REMOVED)) old-sessions))
	       ((string= (php-session:session-id (car old-sessions))
			 (php-session:session-id (car new-sessions)))
		(let ((diff (php-session:diff (car old-sessions) (car new-sessions))))
		  (if diff 
		      (cons (cons diff :CHANGED)
			    (php-sessions-diff (cdr old-sessions) (cdr new-sessions)))
		      (php-sessions-diff (cdr old-sessions) (cdr new-sessions)))))
	       ((string< (php-session:session-id (car old-sessions))
			 (php-session:session-id (car new-sessions)))
		(cons (cons (car old-sessions) :DELETED)
		      (php-sessions-diff (cdr old-sessions) new-sessions)))
	       ((string> (php-session:session-id (car old-sessions))
			 (php-session:session-id (car new-sessions)))
		(cons (cons (car new-sessions) :ADDED)
		      (php-sessions-diff old-sessions (cdr new-sessions)))))))
    (make-php-session-diff-entry :diffs (php-sessions-diff (php-sessions old) (php-sessions new)))))


;in this function are debug prints
(defun make-php-session-history-state (php-session-folder user host pwd)
  (make-instance 'php-session-state
		 :php-sessions (sort (mapcar #'(lambda(php-session-file)
						 (FORMAT T "get/parse file:~a~%" php-session-file)
						 (cl-fad:with-open-temporary-file (stream :direction :io :element-type 'character)
						   (ssh:scp php-session-file (pathname stream) user host pwd)
						   (finish-output stream)
						   (php-session:parse-php-session stream 
										  (php-session:extract-session-id php-session-file))))
					     (ssh:folder-content-guest php-session-folder user host pwd))
				     #'string<=
				     :key #'php-session:session-id)))
