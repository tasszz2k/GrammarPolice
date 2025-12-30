# GrammarPolice

[![GitHub license](https://img.shields.io/github/license/tasszz2k/GrammarPolice)](https://github.com/tasszz2k/GrammarPolice/blob/main/LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/tasszz2k/GrammarPolice)](https://github.com/tasszz2k/GrammarPolice/stargazers)
[![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange)](https://swift.org/)

A powerful macOS menubar app for instant grammar correction and translation using AI. Works with any application through global hotkeys.

**Repository:** [https://github.com/tasszz2k/GrammarPolice](https://github.com/tasszz2k/GrammarPolice)

<!-- Add app icon here -->
![App Icon](docs/images/app-icon.png)

## Features

- **Instant Grammar Correction** - Fix grammar in any app with a single hotkey
- **Multi-language Translation** - Translate from any language to your preferred target language
- **Global Hotkeys** - Works across all applications (Slack, VS Code, browsers, native apps)
- **Custom Words Protection** - Preserve brand names, technical terms, and custom words during correction
- **Multiple LLM Backends** - Support for OpenAI API and local LLMs (Ollama, LM Studio)
- **History Tracking** - View and export your correction/translation history
- **Privacy-focused** - Option to use local LLM for complete privacy

## Demo

<!-- Add demo GIF here -->
![Grammar Correction Demo](docs/gifs/grammar-demo.gif)

### Grammar Correction
Select text in any app and press `Ctrl+Cmd+G` to instantly correct grammar.

<!-- Add grammar correction screenshot -->
![Grammar Correction](docs/images/grammar-correction.png)

### Translation
Select text and press `Ctrl+Cmd+T` to translate to your preferred language.

<!-- Add translation demo GIF -->
![Translation Demo](docs/gifs/translation-demo.gif)

### Preferences
Configure hotkeys, LLM backend, grammar modes, and more.

<!-- Add preferences screenshot -->
![Preferences Window](docs/images/preferences.png)

## Installation

### Requirements
- macOS 14.0 (Sonoma) or later
- Accessibility permission (required for text capture)
- OpenAI API key or local LLM setup

### Install via Homebrew (Recommended)

```bash
brew tap tasszz2k/tap
brew install --cask grammar-police
```

> **Note:** If you see "app is damaged" error, run: `xattr -cr /Applications/GrammarPolice.app`

### Manual Download

Download the latest release from [GitHub Releases](https://github.com/tasszz2k/GrammarPolice/releases):

1. Download `GrammarPolice.zip` from the latest release
2. Unzip and drag `GrammarPolice.app` to your Applications folder
3. Right-click the app and select "Open" (first time only, to bypass Gatekeeper)
4. Grant Accessibility permission when prompted

### Build from Source

1. Clone the repository:
```bash
git clone https://github.com/tasszz2k/GrammarPolice.git
cd GrammarPolice
```

2. Open in Xcode:
```bash
open GrammarPolice.xcodeproj
```

3. Build and run (`Cmd+R`)

### First Launch Setup

1. **Grant Accessibility Permission**
   - Go to System Settings > Privacy & Security > Accessibility
   - Enable GrammarPolice
   
   <!-- Add accessibility permission screenshot -->
   ![Accessibility Permission](docs/images/accessibility-permission.png)

2. **Configure LLM Backend**
   - Open Preferences (click menubar icon > Preferences)
   - Go to LLM tab
   - Enter your OpenAI API key or configure local LLM

## Usage

### Hotkeys

| Hotkey | Action |
|--------|--------|
| `Ctrl+Cmd+G` | Correct grammar of selected text |
| `Ctrl+Cmd+T` | Translate selected text |

### Grammar Modes

| Mode | Description |
|------|-------------|
| **Minimal** | Fixes only grammar errors, preserves original tone |
| **Friendly** | Corrects grammar with a friendly, casual tone |
| **Work** | Professional, business-appropriate corrections |
| **Custom** | Use your own prompts for custom behavior |

### Translation

- Supports **any source language** - auto-detected
- Target languages: Vietnamese (default), English, Chinese, Japanese, Korean, Spanish, French, German, and more
- Translation appears in a dialog window (does not modify clipboard)

### Custom Words

Protect specific words from being modified during correction:

<!-- Add custom words screenshot -->
![Custom Words](docs/images/custom-words.png)

Examples:
- Brand names: `GrammarPolice`, `iPhone`, `OpenAI`
- Technical terms: `API`, `JSON`, `OAuth`
- Names: `John Doe`, `Acme Corp`

## Configuration

### LLM Backends

#### OpenAI (Recommended)
1. Get an API key from [OpenAI](https://platform.openai.com/)
2. Enter the key in Preferences > LLM
3. Select model (gpt-4o-mini recommended for speed/cost balance)

#### Local LLM
For complete privacy, use a local LLM:

**Ollama:**
```bash
# Install Ollama
brew install ollama

# Pull a model
ollama pull llama3

# Start Ollama server
ollama serve
```

Then configure in Preferences:
- Mode: HTTP Endpoint
- Endpoint: `http://localhost:11434/api/generate`
- Model: `llama3`

**LM Studio:**
1. Download and install [LM Studio](https://lmstudio.ai/)
2. Download a model
3. Start the local server
4. Configure endpoint in Preferences

## Screenshots

### Menubar Icon
<!-- Add menubar screenshot -->
![Menubar](docs/images/menubar.png)

### Grammar Settings
<!-- Add grammar settings screenshot -->
![Grammar Settings](docs/images/grammar-settings.png)

### LLM Settings
<!-- Add LLM settings screenshot -->
![LLM Settings](docs/images/llm-settings.png)

### History View
<!-- Add history screenshot -->
![History](docs/images/history.png)

### Export For Learning
![Learning](docs/images/export-for-learning.png)

You can use this data to improve language skills.

```json
[
   {
    "input" : "supposed",
    "correction" : "giả định",
    "explanation" : "Mode: translate"
  },
  {
    "correction" : "I already checked the log yesterday, but it doesn't show anything wrong, so maybe the issue does not come from the backend.",
    "explanation" : "Mode: grammar",
    "input" : "i already check the log yesterday but it doesnt show anything wrong so maybe the issue is not come from backend"
  },
  {
    "input" : "this thing not working as it suppose to be and i really dont know why it keep failing again and again",
    "correction" : "This thing is not working as it is supposed to, and I really don't know why it keeps failing again and again.",
    "explanation" : "Mode: grammar"
  },
  {
    "input" : "hey guys sorry for late reply i was busy handle other task and didnt have time to look into this issue",
    "correction" : "Hey guys, sorry for the late reply. I was busy handling other tasks and didn't have time to look into this issue.",
    "explanation" : "Mode: grammar"
  },
]
```

### Debug Logs
<!-- Add debug logs screenshot -->
![Debug Logs](docs/images/debug-logs.png)

## Supported Applications

GrammarPolice works with virtually any application:

| App Type | Text Capture | Text Replacement |
|----------|--------------|------------------|
| Native macOS apps (Notes, TextEdit, Pages) | Accessibility API | Direct replacement |
| Electron apps (Slack, Discord, VS Code) | Clipboard fallback | Paste simulation |
| Browsers (Safari, Chrome, Firefox) | Clipboard fallback | Paste simulation |
| Terminal apps | Clipboard fallback | Paste simulation |

## Troubleshooting

### "App is damaged and can't be opened"

![App Damaged Warning](docs/images/warning-cant-be-install.png)

This happens because the app is not code-signed. Run this command to fix:
```bash
xattr -cr /Applications/GrammarPolice.app
```

### Hotkeys not working
1. Check Accessibility permission is granted
2. Restart the app after granting permission
3. Check for conflicting hotkeys in other apps

### No text captured
1. Ensure text is selected before pressing hotkey
2. Some apps may require clipboard fallback (automatic)
3. Check debug logs for details

### LLM errors
1. Verify API key is correct
2. Check internet connection
3. For local LLM, ensure server is running

## Privacy

- **OpenAI Mode**: Selected text is sent to OpenAI's servers
- **Local LLM Mode**: All processing happens locally on your machine
- No telemetry or analytics
- History stored locally in SwiftData

## Tech Stack

- **Swift 5** / **SwiftUI** / **AppKit**
- **SwiftData** for history persistence
- **Keychain** for secure API key storage
- **Accessibility APIs** for text capture
- **NSEvent** for global hotkey monitoring

## License

MIT License - see [LICENSE](https://github.com/tasszz2k/GrammarPolice/blob/main/LICENSE) for details.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## Acknowledgments

- OpenAI for the GPT API
- The macOS developer community

---

Made with care for better writing everywhere.
