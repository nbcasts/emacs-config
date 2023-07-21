;;; TODO: bundler wrapper
;;; TODO: allow to skip docker wrapper
;;; TODO: compile multiple to receive a list of commands with arguments // (rr/compile-multiple '(("rubocop" (current-file)) ("rubocop --autocorrect" (current-file)) ("rubocop" (current-file))))

;;; Code:
(require 'ruby-mode)
(require 'ansi-color)
(require 'compile)

(defvar ruby-runner-mode-keymap)
(define-prefix-command 'ruby-runner-mode-keymap)

(defcustom ruby-runner-key-command-prefix  (kbd "C-c .")
  "The prefix for all ruby-runner related key commands."
  :type 'string
  :group 'ruby-runner-mode)

(define-prefix-command 'ruby-runner-mode-keymap)

(defgroup ruby-runner-mode nil
  "RubyRunner minor mode."
  :group 'languages)

(defcustom ruby-runner-docker-cwd "/app/"
  "Working directory when running inside Docker.  Use trailing slash."
  :type 'string
  :group 'ruby-runner-mode)

(defvar ruby-runner-last-command nil)

(defun rr/parent-directory (a-directory)
  "Returns the directory of which A-DIRECTORY is a child"
  (file-name-directory (directory-file-name a-directory)))

(defun rr/project-root-directory-p (directory)
  (or (file-regular-p (expand-file-name "Rakefile" directory))
      (file-regular-p (expand-file-name "Gemfile" directory))))

(defun rr/root-directory-p (a-directory)
  "Return t if A-DIRECTORY is the root."
  (equal a-directory (rr/parent-directory a-directory)))

(defun rr/project-root (&optional directory)
  "Find the root directory of the project.
Walk the directory tree until it finds a rake file."
  (let ((directory (file-name-as-directory (or directory default-directory))))
    (cond ((rr/root-directory-p directory)
           (error "Could not determine the project root."))
          ((rr/project-root-directory-p directory) (expand-file-name directory))
          (t (rr/project-root (file-name-directory (directory-file-name directory)))))))

(defun rr/container-file-name (file-name)
  (if file-name
      (replace-regexp-in-string
       (concat "^" (rr/project-root file-name))
       rr/docker-cwd
       file-name
       )
    file-name))

(defun rr/define-target-file-name-or-empty (target)
  (if target target ""))

(defun rr/define-target-path (target)
  (concat " " (rr/define-target-file-name-or-empty target)))

(defun rr/run-command-on-target (command-name &optional target)
  (concat
   command-name
   (rr/define-target-path target))
  )

(defcustom rr/docker-command "docker-compose run --rm web sh -c"
  "Docker command to run."
  :type 'string
  :group 'rr/mode
  :safe 'stringp)

(defun rr/docker-p ()
  (or (file-readable-p (concat (rr/project-root) "docker-compose.yml"))
      (file-readable-p (concat (rr/project-root) "docker-compose.yaml"))))

(defun rr/docker-wrapper (command-name target)
  "Docker wrapper for command"
  (if (rr/docker-p)
      (rr/run-command-on-target
       (concat rr/docker-command " \"" command-name "\" " (rr/container-file-name target)))
    (concat " " command-name " " target))
  )

(defun rr/compile-command (command-name &optional target)
  "Composes the command line for compile function"
  (rr/docker-wrapper command-name target))

(defun rr/compile (command-name &optional target)
  "Actually compile"
  (setq rr/last-command (rr/compile-command command-name target))
  (compile (rr/compile-command command-name target))
  (file-relative-name target (rr/project-root))
  )

(defun rr/compile-multiple (commands)
  (compile (mapconcat 'rr/compile-command commands " && "))
  )

(defun rr/rerun ()
  "Re-run the last RSpec invocation."
  (interactive)
  (compile rr/last-command))

(defun rr/global-set-key (key command &optional target)
  "Set a global key binding to invoke (rr/compile command target)."
  (which-key-add-key-based-replacements key command)
  (global-set-key (kbd key)
                  `(lambda ()
                     (interactive)
                     (rr/compile ,command ,target))))

;; (defun rr/global-set-key-current-file (key command)
;;   "Set a global key binding to invoke (rr/compile command target)."
;;   (which-key-add-key-based-replacements key (concat command " current file"))

;;     (global-set-key (kbd key)
;;                     `(lambda ()
;;                        (interactive)
;;                        (rr/compile ,command ,@buffer-file-name))))

(defun rr/global-set-key-multiple (key commands)
  "Set a global key binding to invoke (rr/compile-multiple commands)."
  (which-key-add-key-based-replacements key (mapconcat 'identity commands " && "))
  (global-set-key (kbd key)
                  `(lambda ()
                     (interactive)
                     (rr/compile-multiple ',commands))))
;;;###autoload
(define-minor-mode ruby-runner-mode
  "Minor mode for running ruby commands

\\{ruby-runner-mode-map}"
  :lighter " RR" :keymap `((,ruby-runner-key-command-prefix . ruby-runner-mode-keymap))
  )

(provide 'ruby-runner-mode)

;;; ruby-runner-mode.el ends here
