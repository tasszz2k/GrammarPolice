# Changelog

All notable changes to GrammarPolice will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.10](https://github.com/tasszz2k/GrammarPolice/compare/v0.0.9...v0.0.10) (2026-04-27)


### Bug Fixes

* **release:** generate p12 with -legacy so security import works ([#10](https://github.com/tasszz2k/GrammarPolice/issues/10)) ([dda6cb6](https://github.com/tasszz2k/GrammarPolice/commit/dda6cb6b090107fe1237bbb1396991463e6db4ea))

## [0.0.9](https://github.com/tasszz2k/GrammarPolice/compare/v0.0.8...v0.0.9) (2026-04-27)


### Bug Fixes

* **release:** diagnose and harden PKCS12 import in CI signing step ([#8](https://github.com/tasszz2k/GrammarPolice/issues/8)) ([0c8d7a4](https://github.com/tasszz2k/GrammarPolice/commit/0c8d7a4ed102b841b80545175c99840c425f1d49))

## [0.0.8](https://github.com/tasszz2k/GrammarPolice/compare/v0.0.7...v0.0.8) (2026-04-27)


### Bug Fixes

* **hotkey:** consume global hotkeys via Carbon to stop leaking to focused app ([8ded0b0](https://github.com/tasszz2k/GrammarPolice/commit/8ded0b058e35ea5a7eafd4fb49392de0288092b4))
* **release:** sign release builds with a stable self-signed cert ([def39b9](https://github.com/tasszz2k/GrammarPolice/commit/def39b9e0135d78b057c8d0fc31bef35e5538bb9))
* **release:** sign release builds with a stable self-signed cert ([77ef68f](https://github.com/tasszz2k/GrammarPolice/commit/77ef68f55b9491e92ad64060f74888d7926184ae))

## [0.0.7](https://github.com/tasszz2k/GrammarPolice/compare/v0.0.6...v0.0.7) (2026-04-27)


### Bug Fixes

* **selection:** route Cursor and other Electron VSCode forks through clipboard fallback ([966797a](https://github.com/tasszz2k/GrammarPolice/commit/966797a90a3ab89fe8852cbcf377834493b780b8))

## [0.0.6](https://github.com/tasszz2k/GrammarPolice/compare/v0.0.5...v0.0.6) (2026-03-16)


### Bug Fixes

* **export:** use static reference for AutoExportService access ([af29ede](https://github.com/tasszz2k/GrammarPolice/commit/af29ede3057cb8b662a0d1462cf6869a78fd0244))

## [0.0.5](https://github.com/tasszz2k/GrammarPolice/compare/v0.0.4...v0.0.5) (2026-03-16)


### Features

* **export:** add manual Export Now button to settings ([267dd7c](https://github.com/tasszz2k/GrammarPolice/commit/267dd7c20a1d8a6fd819c7050f58655f707d8170))


### Bug Fixes

* sync app version with release-please tag in CI builds ([32cec4b](https://github.com/tasszz2k/GrammarPolice/commit/32cec4b30f6845c613f0a0f33bbce10770675777))

## [0.0.4](https://github.com/tasszz2k/GrammarPolice/compare/v0.0.3...v0.0.4) (2026-03-15)


### Bug Fixes

* add workflow_dispatch trigger to homebrew workflow ([0bef113](https://github.com/tasszz2k/GrammarPolice/commit/0bef113e0be4bcaebda83d7c74313fdb44dee798))
* use workflow_run trigger for homebrew publish ([c1dbe0a](https://github.com/tasszz2k/GrammarPolice/commit/c1dbe0ac8c4f8d7417de917915391e6c5fcbfa8e))

## [0.0.3](https://github.com/tasszz2k/GrammarPolice/compare/v0.0.2...v0.0.3) (2026-03-15)


### Features

* add fallback floating notifications for systems without Push Notifications capability ([3fb9fd4](https://github.com/tasszz2k/GrammarPolice/commit/3fb9fd42a285efd6fab0e28f7263c28726746264))
* add selection context, custom model input, auto-export, release-please, and dynamic version ([324f42d](https://github.com/tasszz2k/GrammarPolice/commit/324f42d16f16898d6ce372d1813bc73d074e3637))

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
