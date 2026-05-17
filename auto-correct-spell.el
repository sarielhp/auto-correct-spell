;;; auto-correct-spell.el --- Auto-correct from jinx corrections  -*- lexical-binding: t; -*-

;; Author: Gemini CLI
;; Version: 0.2.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: convenience, wp
;; URL: https://github.com/sarielhp/auto-correct-spell

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; `auto-correct-spell' integrates spellcheckers (Jinx, Ispell, Flyspell)
;; with Emacs abbrevs. Every time you correct a word, an abbrev is
;; automatically created for the current mode (or globally). This allows
;; future typos to be corrected instantly as you type.
;;
;; Features:
;; - Automatically creates abbrev entries from corrections.
;; - Supports Jinx, Ispell, and Flyspell backends.
;; - Filters out short words and non-alphabetic strings.
;; - Persists new abbrevs to your `abbrev-file-name' immediately.
;; - Provides a command to quickly remove the last added correction.
;;
;; Installation:
;; (require 'auto-correct-spell)
;; (auto-correct-spell-mode 1)

;;; Code:

(require 'abbrev)
(require 'subr-x)

(defgroup auto-correct-spell nil
  "Automatic abbrev creation from spellcheck corrections."
  :group 'editing)

(defcustom auto-correct-spell-min-length 5
  "Minimum length of misspelled word to be added as an abbrev."
  :type 'integer
  :group 'auto-correct-spell)

(defcustom auto-correct-spell-backends '(jinx ispell flyspell)
  "List of backends to integrate with.
Supported backends: `jinx', `ispell', `flyspell'."
  :type '(set (const jinx) (const ispell) (const flyspell))
  :group 'auto-correct-spell)

(defvar auto-correct-spell--last-abbrev nil
  "Last abbrev added, as a cons (SYMBOL . TABLE).")

;;;###autoload
(defun auto-correct-spell-remove-last-abbrev ()
  "Remove the last added auto-correct abbrev and save the abbrev file.
This is useful if you accidentally corrected a word to something
you didn't intend to be a permanent abbrev."
  (interactive)
  (if-let* ((data auto-correct-spell--last-abbrev)
            (symbol (car data))
            (table (cdr data)))
      (progn
        (unintern (symbol-name symbol) table)
        (when abbrev-file-name
          (write-abbrev-file abbrev-file-name))
        (message "auto-correct-spell: Removed abbrev '%s'" (symbol-name symbol))
        (setq auto-correct-spell--last-abbrev nil))
    (user-error "auto-correct-spell: No abbrev to remove")))

(defun auto-correct-spell--valid-word-p (word)
  "Return non-nil if WORD is a valid candidate for an abbrev.
A valid word must be purely alphabetic and meet the minimum length."
  (and (stringp word)
       (>= (length word) auto-correct-spell-min-length)
       (string-match-p "^[[:alpha:]]+$" word)))

(defun auto-correct-spell--add-abbrev (old-word new-word &optional buffer)
  "Add OLD-WORD -> NEW-WORD to the appropriate abbrev table.
Uses the `local-abbrev-table' of BUFFER (if provided or current),
falling back to `global-abbrev-table'.  Saves to `abbrev-file-name' immediately."
  (let* ((old-clean (substring-no-properties old-word))
         (new-clean (substring-no-properties new-word))
         (abbrev (downcase old-clean)))
    (if (not (auto-correct-spell--valid-word-p abbrev))
        (message "auto-correct-spell: Skipped \"%s\" (must be alphabetic and >= %d chars)" 
                 old-clean auto-correct-spell-min-length)
      (with-current-buffer (or buffer (current-buffer))
        (let ((table (or local-abbrev-table global-abbrev-table)))
          (if (not table)
              (message "auto-correct-spell: Warning - No abbrev table available")
            (if (string= abbrev (downcase new-clean))
                (message "auto-correct-spell: Skipped \"%s\" (identical expansion)" old-clean)
              (progn
                ;; define-abbrev handles lowercase automatically if table is so configured,
                ;; but we enforce it here for consistency.
                (define-abbrev table abbrev new-clean)
                (let ((sym (abbrev-symbol abbrev table)))
                  (put sym 'auto-correct-spell t)
                  (setq auto-correct-spell--last-abbrev (cons sym table)))
                ;; Ensure persistence immediately
                (when abbrev-file-name
                  (condition-case err
                      (progn
                        (write-abbrev-file abbrev-file-name)
                        (setq abbrevs-changed nil))
                    (error (message "auto-correct-spell: Error saving abbrev file: %s" err))))
                ;; Feedback to user
                (let ((msg (format "autocorrect added: \"%s\" -> \"%s\"" old-clean new-clean)))
                  (message "%s" msg)
                  (run-with-timer 0.1 nil (lambda (m) (message "%s" m)) msg))))))))))

(defun auto-correct-spell--jinx-advice (overlay word)
  "Advice for `jinx--correct-replace' to capture corrections from OVERLAY to WORD."
  (let ((buf (overlay-buffer overlay)))
    (when (and buf (buffer-live-p buf))
      (with-current-buffer buf
        (let* ((start (overlay-start overlay))
               (end (overlay-end overlay))
               (old-word (and start end (buffer-substring-no-properties start end))))
          (when old-word
            (auto-correct-spell--add-abbrev old-word word buf)))))))

(defun auto-correct-spell--ispell-advice (res _miss _guess word &rest _args)
  "Advice for `ispell-command-loop' to capture corrections of WORD.
RES is the return value of `ispell-command-loop'."
  (when (and (stringp word) (or (stringp res) (and (listp res) (stringp (car res)))))
    (let ((new-word (if (stringp res) res (car res))))
      (auto-correct-spell--add-abbrev word new-word)))
  res)

(defun auto-correct-spell--flyspell-advice (replace _poss word &rest _args)
  "Advice for `flyspell-do-correct' to capture corrections of WORD to REPLACE."
  (when (and (stringp word) (or (stringp replace) (and (listp replace) (stringp (car replace)))))
    (let ((new-word (if (stringp replace) replace (car replace))))
      (auto-correct-spell--add-abbrev word new-word))))

(defun auto-correct-spell--expand-abbrev-advice (sym)
  "Advice for `expand-abbrev' to notify when a SYM was expanded by this package."
  (when (and sym (symbolp sym) (get sym 'auto-correct-spell))
    (message "Auto-corrected '%s' to '%s'.  Undo with M-x auto-correct-spell-remove-last-abbrev"
             (symbol-name sym) (symbol-value sym)))
  sym)

;;;###autoload
(define-minor-mode auto-correct-spell-mode
  "Global minor mode to automatically turn spellcheck corrections into abbrevs.

When this mode is enabled, every time you correct a word using Jinx,
Ispell, or Flyspell, an abbrev is created.  If the misspelling is
typed again, it will be automatically expanded to the correct form."
  :global t
  :group 'auto-correct-spell
  (if auto-correct-spell-mode
      (progn
        (when (memq 'jinx auto-correct-spell-backends)
          (advice-add 'jinx--correct-replace :before #'auto-correct-spell--jinx-advice))
        (when (memq 'ispell auto-correct-spell-backends)
          (advice-add 'ispell-command-loop :filter-return #'auto-correct-spell--ispell-advice))
        (when (memq 'flyspell auto-correct-spell-backends)
          (advice-add 'flyspell-do-correct :before #'auto-correct-spell--flyspell-advice))
        (advice-add 'expand-abbrev :filter-return #'auto-correct-spell--expand-abbrev-advice))
    (advice-remove 'jinx--correct-replace #'auto-correct-spell--jinx-advice)
    (advice-remove 'ispell-command-loop #'auto-correct-spell--ispell-advice)
    (advice-remove 'flyspell-do-correct #'auto-correct-spell--flyspell-advice)
    (advice-remove 'expand-abbrev #'auto-correct-spell--expand-abbrev-advice)))

(provide 'auto-correct-spell)
;;; auto-correct-spell.el ends here

