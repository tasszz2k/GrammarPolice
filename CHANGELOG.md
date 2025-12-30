# Changelog

All notable changes to GrammarPolice will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.2] - 2025-12-30

### Added

- **Homebrew Installation**: Install via `brew tap tasszz2k/tap && brew install --cask grammar-police`
- **Automated Homebrew Publishing**: GitHub Actions now auto-updates Homebrew tap on release
- **About Dialog Improvements**: 
  - Fixed hotkey display (now shows correct Ctrl+Cmd+G/T)
  - Added author (Tass) and GitHub repository link
  - Added "Open GitHub" button

### Fixed

- Fixed incorrect hotkeys shown in About dialog (was Cmd+Shift, now Ctrl+Cmd)
- Fixed version number display in About dialog

---

## [0.0.1] - 2025-12-30

### Added

- **Menubar App**: Lives in the macOS menubar for quick access without cluttering the Dock
- **Global Hotkeys**: 
  - `Ctrl+Cmd+G` for grammar correction
  - `Ctrl+Cmd+T` for translation
- **Grammar Correction**: 
  - Fixes grammar, spelling, and punctuation in selected text
  - Supports multiple modes: Standard, Formal, Casual, and Custom
  - Automatically replaces selected text with corrected version
- **Translation**: 
  - Translates selected text to your target language
  - Supports 15+ languages including Vietnamese, English, Chinese, Japanese, Korean, Spanish, French, German, and more
  - Shows translation in a dialog without modifying clipboard
- **LLM Backend Support**:
  - OpenAI API integration (GPT-4, GPT-4o, GPT-4o-mini, GPT-4.1-mini)
  - Local LLM support via CLI commands or HTTP endpoints (Ollama compatible)
- **Custom Words**: Preserve specific words/phrases (brand names, technical terms) during correction
- **History**: View and export correction/translation history (CSV/JSON)
- **Preferences Window**:
  - General settings (launch at login, hotkey customization)
  - Grammar mode and custom prompt configuration
  - LLM backend configuration with connection testing
  - Custom words management with import/export
  - History viewer with search and export
  - Debug logging with adjustable verbosity
- **Accessibility API Integration**: Direct text replacement in supported apps
- **Clipboard Fallback**: Works with apps that don't support Accessibility APIs (Slack, Discord, VS Code, etc.)
- **Notifications**: User feedback for operations, errors, and permission requirements
- **Privacy**: Local LLM option for complete data privacy; API keys stored in Keychain

### Technical

- Built with Swift 5 and SwiftUI for macOS 14.0+
- SwiftData for persistent history storage
- Non-sandboxed for Accessibility API access
- GitHub Actions CI/CD for automated builds

### Known Limitations

- Requires Accessibility permission for global hotkeys and text manipulation
- Some Electron-based apps may require clipboard fallback mode
- Translation display uses system alert dialog (notification truncates long text)

---

[0.0.2]: https://github.com/tasszz2k/GrammarPolice/releases/tag/v0.0.2
[0.0.1]: https://github.com/tasszz2k/GrammarPolice/releases/tag/v0.0.1

