;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Maintain a chess game that is being played or viewed
;;
;; $Revision$

;;; Commentary:

;; A chess game is represented by a set of tags that describe the
;; game, and a list of plies representing the main variation.

(require 'chess-ply)

(defvar chess-game-inhibit-events nil)

(defconst chess-game-default-tags
  `(("Event"	   . "Computer chess game")
    ("Round"	   . "-")
    ("Site"	   . ,(system-name))
    ("White"	   . "?")
    ("Black"	   . "?")
    ("Result"	   . "*")
    ("TimeControl" . "-")))

(defsubst chess-game-hooks (game)
  "Return the tags alist associated with GAME."
  (car game))

(defsubst chess-game-set-hooks (game hooks)
  "Return the tags alist associated with GAME."
  (setcar game hooks))

(defun chess-game-add-hook (game function &optional data prepend)
  "Return the tags alist associated with GAME."
  (let ((hooks (chess-game-hooks game)))
    (if (null hooks)
	(chess-game-set-hooks game (list (cons function data)))
      (if prepend
	  (chess-game-set-hooks game (cons (cons function data) hooks))
	(nconc hooks (list (cons function data)))))))

(defun chess-game-remove-hook (game function &optional data)
  "Remove from GAME all event hooks that match FUNCTION.
If DATA is specified, only remove those hooks whose associated data
matches."
  (let* ((hooks (chess-game-hooks game))
	 (h hooks) last-hook)
    (while h
      (if (and (eq (caar h) function)
	       (or (null data)
		   (eq data (cdar h))))
	  (if last-hook
	      (setcdr last-hook (cdr h))
	    (setq hooks (cdr h)))
	(setq last-hook h))
      (setq h (cdr h)))
    (chess-game-set-hooks game hooks)))

(defsubst chess-game-run-hooks (game &rest args)
  "Return the tags alist associated with GAME."
  (unless chess-game-inhibit-events
    (dolist (hook (chess-game-hooks game))
      (apply (car hook) game (cdr hook) args))))


(defsubst chess-game-tags (game)
  "Return the tags alist associated with GAME."
  (cadr game))

(defsubst chess-game-set-tags (game tags)
  "Return the tags alist associated with GAME."
  (setcar (cdr game) tags)
  (chess-game-run-hooks game 'set-tags))

(defsubst chess-game-tag (game tag)
  "Return the value for TAG in GAME."
  (let ((tags (chess-game-tags game)))
    (and tags (cdr (assoc tag tags)))))

(defun chess-game-set-tag (game tag value)
  "Set a TAG for GAME to VALUE."
  (let ((tags (chess-game-tags game)))
    (if (null tags)
	(chess-game-set-tags game (list (cons tag value)))
      (let ((entry (assoc tag tags)))
	(if entry
	    (setcdr entry value)
	  (nconc tags (list (cons tag value)))))))
  (chess-game-run-hooks game 'set-tag tag))

(defsubst chess-game-del-tag (game tag)
  "Set a TAG for GAME to VALUE."
  (chess-game-set-tags game (assq-delete-all tag (chess-game-tags game)))
  (chess-game-run-hooks game 'delete-tag tag))


(defsubst chess-game-data-alist (game)
  (nth 2 game))

(defun chess-game-set-data (game key value)
  (let* ((alist (chess-game-data-alist game))
	 (cell (assq key alist)))
    (if cell
	(setcdr cell value)
      (if (null alist)
	  (setcar (nthcdr 2 game) (list (cons key value)))
	(push (cons key value) alist)
	(setcar (nthcdr 2 game) alist)))
    (chess-game-run-hooks game 'set-data key)))

(defun chess-game-data (game key)
  (let ((alist (chess-game-data-alist game)))
    (if alist
	(cdr (assq key alist)))))

(defun chess-game-del-data (game key)
  (let ((alist (chess-game-data-alist game)))
    (if alist
	(assq-delete-all key alist))))


(defsubst chess-game-plies (game)
  "Return the tags alist associated with GAME."
  (nth 3 game))

(defalias 'chess-game-main-var 'chess-game-plies)

(defsubst chess-game-set-plies (game plies)
  "Return the tags alist associated with GAME."
  (setcdr (nthcdr 2 game) (list plies))
  (chess-game-run-hooks game 'setup-game))

(defsubst chess-game-set-start-position (game position)
  "Return the tags alist associated with GAME."
  (chess-game-set-plies game (list (chess-ply-create position))))

(defsubst chess-game-pos (game &optional index)
  "Return the position related to GAME's INDEX position."
  (chess-ply-pos (chess-game-ply game index)))

(defsubst chess-game-index (game)
  "Return the GAME's current position index."
  (1- (length (chess-game-plies game))))

(defsubst chess-game-seq (game)
  "Return the current GAME sequence."
  (1+ (/ (chess-game-index game) 2)))

(defsubst chess-game-side-to-move (game)
  (chess-pos-side-to-move (chess-game-pos game)))

(defun chess-game-ply (game &optional index)
  "Return the position related to GAME's INDEX position."
  (if index
      (nth index (chess-game-plies game))
    (car (last (chess-game-plies game)))))

(defun chess-game-add-ply (game ply)
  "Return the position related to GAME's INDEX position."
  (let ((plies (chess-game-plies game)))
    (if plies
	(nconc plies (list ply))
      (chess-game-set-plies game (list ply)))))

(defun chess-game-undo (game count)
  "Undo the last COUNT plies of GAME."
  (if (> count (chess-game-index game))
      (error "Cannot undo further")
    (chess-game-set-plies game (nbutlast (chess-game-plies game) count))
    ;;(chess-game-run-hooks game 'undo count)
    ))


(defsubst chess-game-over-p (game)
  "Return the position related to GAME's INDEX position."
  (let ((last-ply (car (last game 2))))
    (and last-ply (chess-ply-final-p last-ply))))


(defsubst chess-game-to-string (game &optional indented)
  (chess-game-to-pgn game indented t))

(defsubst chess-game-from-string (pgn)
  (chess-pgn-to-game pgn))


(defun chess-game-create (&optional position tags)
  "Create a new chess game object.
Optionally use the given starting POSITION.
TAGS is the starting set of game tags (which can always be changed
later using the various tag-related methods)."
  (let ((game (list nil tags nil
		    (list (chess-ply-create (or position
						(chess-pos-create)))))))
    (dolist (tag (cons (cons "Date" (format-time-string "%Y.%m.%d"))
		       chess-game-default-tags))
      (unless (chess-game-tag game (car tag))
	(chess-game-set-tag game (car tag) (cdr tag))))
    game))

(defun chess-game-move (game ply)
  "Make a move in the current GAME, from FROM to TO.
This creates a new position and adds it to the main variation.
The 'changes' of the last ply reflect whether the game is currently in
progress (nil), if it is drawn, resigned, mate, etc."
  (let ((current-ply (chess-game-ply game))
	(changes (chess-ply-changes ply))
	(position (chess-ply-pos ply)))
    (if (chess-ply-final-p current-ply)
	(error "Cannot add moves to a completed game"))
    (unless (equal position (chess-ply-pos current-ply))
      (error "Positions do not match"))
    (chess-ply-set-changes current-ply changes)
    (chess-game-add-ply game (chess-ply-create
			      (chess-ply-next-pos current-ply)))
    (cond
     ((chess-ply-has-keyword ply :draw :perpetual :repetition :stalemate)
      (chess-game-set-tag game "Result" "1/2-1/2")
      (chess-game-run-hooks game 'game-drawn))

     ((chess-ply-has-keyword ply :resign :checkmate)
      (let ((color (chess-game-side-to-move game)))
	(chess-game-set-tag game "Result" (if color "0-1" "1-0"))
	(if (chess-ply-has-keyword ply :resign)
	    (chess-game-run-hooks game 'resign color)
	  (chess-game-run-hooks game 'game-over))))

     (t
      (chess-game-run-hooks game 'move current-ply)))))

(defsubst chess-game-end (game keyword)
  "End the current game, by resignation, draw, etc."
  (chess-game-move game (list (chess-game-pos game) keyword)))

(provide 'chess-game)

;;; chess-game.el ends here
