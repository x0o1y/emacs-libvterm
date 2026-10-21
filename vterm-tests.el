;;; vterm-tests.el --- Local fork regression tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'vterm)

(ert-deftest vterm-test-default-colors-inherit-theme ()
  (should-not (vterm--get-color -1))
  (should-not (vterm--get-color -1 :foreground))
  (should-not (vterm--get-color -1 :underline))
  (should-not (vterm--get-color -1 :foreground :inverse-video)))

(ert-deftest vterm-test-ansi-colors-retain-foreground-and-background ()
  (cl-letf (((symbol-function 'face-foreground)
             (lambda (face &rest _) (list 'foreground face)))
            ((symbol-function 'face-background)
             (lambda (face &rest _) (list 'background face))))
    (dotimes (index 16)
      (should (equal (vterm--get-color index :foreground)
                     (list 'foreground (aref vterm-color-palette index))))
      (should (equal (vterm--get-color index)
                     (list 'background (aref vterm-color-palette index)))))))

(ert-deftest vterm-test-special-default-colors-preserved ()
  (cl-letf (((symbol-function 'face-foreground)
             (lambda (face &rest _) (list 'foreground face)))
            ((symbol-function 'face-background)
             (lambda (face &rest _) (list 'background face))))
    (should (equal (vterm--get-color -1 :foreground :underline)
                   '(foreground vterm-color-underline)))
    (should (equal (vterm--get-color -1 :inverse-video)
                   '(background vterm-color-inverse-video)))))

(ert-deftest vterm-test-rendered-default-background-follows-theme ()
  (let ((fg (face-attribute 'default :foreground))
        (bg (face-attribute 'default :background)))
    (unwind-protect
        (with-temp-buffer
          (set-face-attribute 'default nil :foreground "#eeeeee" :background "#111111")
          (setq-local vterm--term (vterm--new 4 40 10 nil nil nil nil nil nil))
          (vterm--write-input vterm--term "plain\e[48;2;255;0;0mred\e[0m normal")
          (vterm--redraw vterm--term)
          (goto-char (point-min))
          (search-forward "plain")
          (should-not (plist-get (get-text-property (1- (point)) 'font-lock-face) :background))
          (should-not (plist-get (get-text-property (1- (point)) 'font-lock-face) :foreground))
          (search-forward "red")
          (let ((red (get-text-property (1- (point)) 'font-lock-face))
                (text (buffer-string)))
            (should (plist-get red :background))
            (set-face-attribute 'default nil :foreground "#111111" :background "#eeeeee")
            ;; No terminal input, output, or redraw after changing the theme.
            (should (equal text (buffer-string)))
            (should (equal (face-background 'default) "#eeeeee"))
            (should (equal red (get-text-property (1- (point)) 'font-lock-face)))))
      (set-face-attribute 'default nil :foreground fg :background bg))))

(ert-deftest vterm-test-cursor-visibility-default ()
  "Application cursor visibility remains supported with the old argument list."
  (with-temp-buffer
    (setq-local cursor-type 'box)
    (setq-local vterm--term (vterm--new 4 40 10 nil nil nil nil nil nil))
    (vterm--write-input vterm--term "\e[?25l")
    (vterm--redraw vterm--term)
    (should-not cursor-type)
    (vterm--write-input vterm--term "\e[?25h")
    (vterm--redraw vterm--term)
    (should cursor-type)))

(ert-deftest vterm-test-cursor-visibility-setting ()
  "Ignoring visibility preserves the Emacs cursor through terminal hide/show."
  (dolist (ignore '(nil t))
    (with-temp-buffer
      (setq-local cursor-type 'bar)
      (setq-local vterm--term (vterm--new 4 40 10 nil nil nil nil nil t ignore))
      (vterm--write-input vterm--term "\e[?25l")
      (vterm--redraw vterm--term)
      (should (eq cursor-type (when ignore 'bar)))
      (vterm--write-input vterm--term "\e[?25h")
      (vterm--redraw vterm--term)
      (if ignore
          (should (eq cursor-type 'bar))
        (should cursor-type)))))

(ert-deftest vterm-test-cursor-shape-and-visibility-independent ()
  "Ignoring visibility still permits cursor shape changes when configured."
  (with-temp-buffer
    (setq-local cursor-type 'box)
    (setq-local vterm--term (vterm--new 4 40 10 nil nil nil nil nil nil t))
    (vterm--write-input vterm--term "\e[?25l\e[6 q")
    (vterm--redraw vterm--term)
    (should (eq cursor-type 'bar))))

(provide 'vterm-tests)
;;; vterm-tests.el ends here
