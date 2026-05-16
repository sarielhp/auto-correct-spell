# auto-correct-spell

`auto-correct-spell` is an Emacs package that integrates the **Jinx** spellchecker with the built-in **abbrev** system. 

It creates abbrev entries from manual spellcheck corrections, allowing subsequent typos to be corrected automatically as you type.

## How it Works

When you use `jinx-correct` (usually bound to `M-$`) to fix a misspelled word, `auto-correct-spell` captures the replacement. It creates an entry in the local (or global) abbrev table mapping the typo to the chosen correction.

The next time the same typo is typed followed by a trigger character (like `SPC` or `RET`), Emacs expands it to the correct form.

## Features

- **Automated Entry Creation**: Creates abbrevs from Jinx corrections without requiring manual command invocation.
- **Word Filtering**:
    - **Alphabetic Constraint**: Only creates abbrevs for purely alphabetic strings to avoid affecting code or math.
    - **Length Constraint**: Filters out short words based on the `auto-correct-spell-min-length` setting.
- **Persistence**: Saves new entries to your `abbrev-file-name` immediately.
- **Context Awareness**: Prefers `local-abbrev-table` to keep corrections mode-specific when appropriate.
- **Correction Management**: Provides `M-x auto-correct-spell-remove-last-abbrev` to delete the most recently added entry.
- **Feedback**: Displays a message in the echo area when an auto-correction occurs.

## Requirements

- **Emacs 29.1+**
- **[Jinx](https://github.com/minad/jinx)**

## Installation

### Using straight.el

```elisp
(use-package auto-correct-spell
  :straight (auto-correct-spell :type git :host github :repo "your-username/auto-correct-spell")
  :init
  (auto-correct-spell-mode 1))
```

### Manual Installation

1. Clone or download this repository to a directory in your `load-path` (e.g., `~/.emacs.d/lisp/`).
2. Add the following to your `init.el`:

```elisp
(add-to-list 'load-path "~/.emacs.d/lisp/auto-correct-spell")
(require 'auto-correct-spell)
(auto-correct-spell-mode 1)
```

Ensure that the dependencies (`jinx`) are already installed via your preferred package manager.

## Configuration

### `auto-correct-spell-min-length` (Default: 5)
Minimum character length for a typo to be added as an abbrev.

```elisp
(setq auto-correct-spell-min-length 6)
```

## Commands

- **`auto-correct-spell-mode`**: Toggle the global minor mode.
- **`auto-correct-spell-remove-last-abbrev`**: Remove the last added abbrev and save the abbrev file.

## Design Goal

`auto-correct-spell` is intended to reduce the need for repetitive manual corrections. By relying on the user's manual choices during a Jinx session, it ensures that the resulting auto-corrections are based on verified replacements.

## License

GPL-3.0-or-later
