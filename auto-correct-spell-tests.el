;;; auto-correct-spell-tests.el --- Tests for auto-correct-spell  -*- lexical-binding: t; -*-

(require 'ert)
(require 'auto-correct-spell)

(ert-deftest auto-correct-spell-test-valid-word-p ()
  "Test `auto-correct-spell--valid-word-p' logic."
  ;; Valid words
  (should (auto-correct-spell--valid-word-p "example"))
  (should (auto-correct-spell--valid-word-p "Proper"))
  ;; Short words (default min-length is 5)
  (should-not (auto-correct-spell--valid-word-p "test"))
  ;; Non-alphabetic
  (should-not (auto-correct-spell--valid-word-p "word123"))
  (should-not (auto-correct-spell--valid-word-p "word-part"))
  (should-not (auto-correct-spell--valid-word-p "word.ext"))
  ;; Custom min length
  (let ((auto-correct-spell-min-length 3))
    (should (auto-correct-spell--valid-word-p "abc"))))

(ert-deftest auto-correct-spell-test-add-abbrev ()
  "Test `auto-correct-spell--add-abbrev' functionality."
  (let ((local-abbrev-table (make-abbrev-table))
        (global-abbrev-table (make-abbrev-table))
        (abbrev-file-name nil)) ; Don't write to disk
    
    ;; Test adding a valid abbrev
    (auto-correct-spell--add-abbrev "tehst" "test")
    (should (abbrev-expansion "tehst" local-abbrev-table))
    (should (string= (abbrev-expansion "tehst" local-abbrev-table) "test"))
    
    ;; Test skipping short words
    (auto-correct-spell--add-abbrev "tst" "test")
    (should-not (abbrev-expansion "tst" local-abbrev-table))
    
    ;; Test skipping identical expansion
    (auto-correct-spell--add-abbrev "Example" "Example")
    (should-not (abbrev-expansion "example" local-abbrev-table))))

(ert-deftest auto-correct-spell-test-remove-last ()
  "Test `auto-correct-spell-remove-last-abbrev' functionality."
  (let ((local-abbrev-table (make-abbrev-table))
        (abbrev-file-name nil))
    
    (auto-correct-spell--add-abbrev "mistake" "correction")
    (should (abbrev-expansion "mistake" local-abbrev-table))
    
    (auto-correct-spell-remove-last-abbrev)
    (should-not (abbrev-expansion "mistake" local-abbrev-table))
    (should-not auto-correct-spell--last-abbrev)))

(ert-deftest auto-correct-spell-test-mode-toggle ()
  "Test `auto-correct-spell-mode' toggle logic."
  ;; Mock advice functions
  (cl-letf (((symbol-function 'advice-add) (lambda (&rest _) nil))
            ((symbol-function 'advice-remove) (lambda (&rest _) nil)))
    (auto-correct-spell-mode 1)
    (should auto-correct-spell-mode)
    (auto-correct-spell-mode -1)
    (should-not auto-correct-spell-mode)))

(provide 'auto-correct-spell-tests)
;;; auto-correct-spell-tests.el ends here
