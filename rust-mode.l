; $Id: rust-mode.l,v 150115 2015/01/15 00:00:00 Okayu_Sang $
;
; rust-mode for xyzzy
;
; modified by Okayu_Sang

(provide "rust-mode")

(in-package "editor")

(export '(rust-mode
          *rust-keyword-file*
          *rust-mode-hook*
          *rust-mode-syntax-table*
          *rust-indent-offset*
          *rust-cargo-build*
          *rust-cargo-run*
          *rust-rustc-compile*
          rust-build
          rust-run
          ))

; フック
(defvar *rust-mode-hook* nil)

; キーマップ
(defvar *rust-mode-map* nil)
(unless *rust-mode-map*
  (setq *rust-mode-map* (make-sparse-keymap))
  (define-key *rust-mode-map* #\{ 'c-electric-insert)
  (define-key *rust-mode-map* #\: 'c-electric-insert)
  (define-key *rust-mode-map* #\# 'c-electric-insert)
  (define-key *rust-mode-map* #\} 'c-electric-close)
  (define-key *rust-mode-map* #\C-h 'backward-delete-char-untabify-or-selection)
  (define-key *rust-mode-map* #\TAB 'c-indent-line)
  (define-key *rust-mode-map* #\C-M-q 'indent-sexp)
  (define-key *rust-mode-map* #\RET 'c-newline-and-indent)
  (define-key *rust-mode-map* '(#\C-c #\c) 'rust-build)
  (define-key *rust-mode-map* '(#\C-c #\x) 'rust-run)
  )

; キーワード
(defvar *rust-keyword-hash-table* nil)
(defvar *rust-keyword-file* "Rust")

; abbrev
(defvar *rust-mode-abbrev-table* nil)
(unless *rust-mode-abbrev-table*
  (define-abbrev-table '*rust-mode-abbrev-table*))

; シンタックステーブル
(defvar *rust-mode-syntax-table* nil)
(unless *rust-mode-syntax-table*
  (setq *rust-mode-syntax-table* (make-syntax-table))
  (do ((x #x21 (1+ x)))
      ((>= x #x7f))
    (let ((c (code-char x)))
      (unless (alphanumericp c)
        (set-syntax-punctuation *rust-mode-syntax-table* c))))
  (set-syntax-string *rust-mode-syntax-table* #\")
  (set-syntax-escape *rust-mode-syntax-table* #\\)
  (set-syntax-match *rust-mode-syntax-table* #\( #\))
  (set-syntax-match *rust-mode-syntax-table* #\{ #\})
  (set-syntax-match *rust-mode-syntax-table* #\[ #\])
  (set-syntax-start-multi-comment *rust-mode-syntax-table* "/*")
  (set-syntax-end-multi-comment *rust-mode-syntax-table* "*/")
;  (set-syntax-start-comment *rust-mode-syntax-table* #\/)
;  (set-syntax-end-comment *rust-mode-syntax-table* #\LFD nil t)
  (set-syntax-start-c++-comment *rust-mode-syntax-table* #\/)
  (set-syntax-end-c++-comment *rust-mode-syntax-table* #\LFD)
  )

;;環境変数
(defvar *rust-indent-offset* 4)
(defvar *rust-cargo-build* "cargo build --release")
(defvar *rust-cargo-run* "cargo run --release")
(defvar *rust-rustc-compile* "rustc -C opt-level=1")

(defun rust-mode ()
  (interactive)
  (kill-all-local-variables)
  (setq mode-name "Rust")
  (setq buffer-mode 'rust-mode)
  (use-syntax-table *rust-mode-syntax-table*)
  (use-keymap *rust-mode-map*)
  (make-local-variable 'mode-specific-indent-command)
  (setq mode-specific-indent-command 'c-indent-line)
  
  (and *rust-keyword-file*
       (null *rust-keyword-hash-table*)
       (setq *rust-keyword-hash-table*
             (load-keyword-file *rust-keyword-file*)))
  (when *rust-keyword-hash-table*
    (make-local-variable 'keyword-hash-table)
    (setq keyword-hash-table *rust-keyword-hash-table*))
  
;;   (make-local-variable 'regexp-keyword-list)
;;   (setq regexp-keyword-list *rust-variables-regexp*)
  
  (setq *local-abbrev-table* *rust-mode-abbrev-table*)

  (setq comment-start "// ")
  (setq comment-end "")
  (setq comment-start-skip "/\\(\\*+\\|/\\)[ \t]*")
  (setq comment-indent-function 'c-comment-indent)
  
  (run-hooks '*rust-mode-hook*)
  )

(pushnew '(rust-maketags "*.rs") *maketags-list* :key #'car)

(defun rust-maketags (file count)
  (goto-char (point-min))
  (while (scan-buffer "^[ \t]*\\(fn\\|impl\\|trait\\|struct\\)[ \t]+" :regexp t :tail t)
    (do-events)
    (let ((opoint (point)))
      (skip-chars-forward "A-Za-z0-9_")
      (unless (= opoint (point))
        (format t "~A~A~D" (buffer-substring opoint (point)) file opoint)
        (incf count))))
  count)


;;;joinします。sep は "," などセパレータ。cnt は前何番目までをjoinするか。
;;;全件joinしたければ (my-string-join lst (length lst) sep) とする。
(defun rust-string-join (lst cnt sep)
  (cond ((or (null (car lst))
             (= cnt 0))
         "")
        ((null (cdr lst))
         (car lst))
        (t
         (concat (car lst) sep (rust-string-join (cdr lst) (- cnt 1) sep)))))

;;;上位フォルダにファイルがないか調べます。
;;;(rust-file-exist-ancestor-p "C:/some/deep/Rust/src/verydeep/exactly/folder/file.rs" "Cargo.toml")
(defun rust-file-exist-ancestor-p (fullfilename targetfname)
  (let ((lsta (pathname-directory fullfilename))
        (devnm (pathname-device fullfilename))
        (test nil))
    (dotimes (i (length lsta))
      (let ((till (- (length lsta) i)))
        (if (file-exist-p (merge-pathnames targetfname (concat devnm ":/" (rust-string-join lsta till "/"))))
            (progn
;;              (princ (merge-pathnames targetfname (concat devnm ":/" (rust-string-join lsta till "/"))))
              (setf test t)
              (return t)))))
    test))

(defun rust-build ()
  (interactive)
  (let* ((bf (selected-buffer))
         (bufname "*Run Rust*")
         (filename (get-buffer-file-name bf))
         (with-cargo (rust-file-exist-ancestor-p filename "Cargo.toml"))
         )
    (save-buffer)
    (unwind-protect
        (if with-cargo
            (progn
              (pop-to-buffer (get-buffer-create bufname) nil)
              (execute-shell-command *rust-cargo-build* nil bufname nil (directory-namestring filename)))
          (progn
            (pop-to-buffer (get-buffer-create bufname) nil)
            (execute-shell-command
             (format nil "~A \"~A\""
                     (map-slash-to-backslash *rust-rustc-compile*)
                     filename) nil bufname)
            )))
    (switch-to-buffer-other-window bf)
    ))

(defun rust-run ()
  (interactive)
  (let* ((bf (selected-buffer))
         (bufname "*Run Rust*")
         (filename (get-buffer-file-name bf))
         (execname (pathname-name filename))
         (with-cargo (rust-file-exist-ancestor-p filename "Cargo.toml"))
         )
    (save-buffer)
    (unwind-protect
        (if with-cargo
            (progn
              (pop-to-buffer (get-buffer-create bufname) nil)
              (execute-shell-command *rust-cargo-run* nil bufname nil (directory-namestring filename)))
          (progn
            (pop-to-buffer (get-buffer-create bufname) nil)
            (execute-shell-command
             (format nil "~A \"~A\""
                     (map-slash-to-backslash *rust-rustc-compile*)
                     filename) nil bufname)
            (execute-shell-command execname nil bufname))))
    (switch-to-buffer-other-window bf)
    ))

