# xyzzy-rust-mode
A major mode of Rust programming language for xyzzy editor(another emacsen editor)

プログラミング言語Rust用の xyzzy向け major mode です。
これを作った段階では(2015/01) Rustは v1.0.0 α です。まだ本体がαバージョンであることにご留意ください。

キーワードのハイライト。
インデントはC-modeのものをそのまま使う感じ。
C-c c で cargo管理してたら cargo build --release を、
        cargo管理してなさそうなら rustc -C opt-level=1 を。
C-c x で cargo run --release だったり ファイル名.exe を起動したり。

使い方：一例ですが、
(load-library "rust-mode")
(push '("\\.rs$" . rust-mode) *auto-mode-alist*)
(add-hook 'ed::*rust-mode-hook*
          #'(lambda ()
              (set-buffer-fileio-encoding *encoding-utf8*) ;;change-fileio-encoding
              (ed::set-buffer-local 'indent-tabs-mode nil) ;;indentにTABを使わない
              (setq *c-tab-always-indent* nil)
              (setq *c-indent-tabs-mode* nil)
              (setq c-indent-level 4)
              (define-key ed::*rust-mode-map* #\F8 'rust-build)
              (define-key ed::*rust-mode-map* #\S-F8 'rust-run)
              )
          )

こんな感じ。
ac-modeもそのまま使えます。
TAG系は特になにもやってません。
