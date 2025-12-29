# GrammarPolice

A macOS menubar application for grammar correction and translation using AI. Select text in any application, press a hotkey, and get instant corrections or translations.

## Features

- **Global Hotkeys**: Correct grammar (Cmd+Shift+G) or translate (Cmd+Shift+T) from any application
- **Accessibility API Integration**: Reads and replaces selected text directly in supported apps
- **Custom Words Protection**: Define words that should never be modified by the AI
- **Multiple Grammar Modes**: Minimal, Friendly, Work, or Custom prompts
- **Translation**: Translate to any language (default: Vietnamese)
- **OpenAI Integration**: Uses GPT-4o-mini or other OpenAI models
- **Local LLM Support**: Connect to local LLM servers like Ollama
- **History Tracking**: View and export your correction/translation history
- **Privacy-Focused**: Requires explicit consent before sending text to remote services

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- OpenAI API key (for cloud-based corrections)

## Building

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd GrammarPolice
   ```

2. Open the project in Xcode:
   ```bash
   open GrammarPolice.xcodeproj
   ```

3. Build and run (Cmd+R)

## Permissions

GrammarPolice requires the following permissions to function properly:

### Accessibility Permission (Required)

The app needs Accessibility permission to read and replace selected text across applications.

1. When you first run the app, macOS will prompt you to grant Accessibility permission
2. Go to **System Settings > Privacy & Security > Accessibility**
3. Enable the toggle for **GrammarPolice**
4. You may need to restart the app after granting permission

### Notifications Permission (Recommended)

Enable notifications to receive feedback when text is corrected or translated.

1. Go to **System Settings > Notifications > GrammarPolice**
2. Enable notifications

### Keychain Access

The app stores your OpenAI API key securely in the macOS Keychain.

## Configuration

### OpenAI API Key

1. Open Preferences (click the menubar icon and select "Preferences...")
2. Go to the **LLM** tab
3. Click "Set" next to "API Key"
4. Enter your OpenAI API key
5. Click "Test Connection" to verify

### Custom Words

Protect specific words from being modified:

1. Open Preferences
2. Go to the **Custom Words** tab
3. Click "Add" to add words
4. Configure case sensitivity and whole-word matching as needed
5. Import/Export word lists using CSV format

### Grammar Modes

- **Minimal**: Makes only necessary grammar corrections
- **Friendly**: Adjusts tone to be more friendly
- **Work**: Professional business writing tone
- **Custom**: Define your own system and user prompts

### Local LLM

To use a local LLM instead of OpenAI:

1. Open Preferences > LLM tab
2. Select "Local LLM" as the backend
3. Choose CLI or HTTP mode
4. Configure the command or endpoint (e.g., `http://localhost:11434` for Ollama)

## Usage

1. Select text in any application
2. Press the hotkey:
   - **Cmd+Shift+G**: Correct grammar
   - **Cmd+Shift+T**: Translate
3. The corrected/translated text will either:
   - Replace the selection directly (in supported apps)
   - Be copied to clipboard (use Cmd+V to paste)

## Hotkey Customization

1. Open Preferences > General tab
2. Click "Change" next to the hotkey you want to modify
3. Press the new key combination
4. The hotkey will be updated immediately

## History

View your correction and translation history:

1. Open Preferences > History tab
2. Filter by mode (Grammar/Translate)
3. Search by content
4. Export to CSV or JSON
5. Purge old entries

## Project Structure

```
GrammarPolice/
  GrammarPolice/
    AppDelegate.swift           # App lifecycle management
    MenubarController.swift     # Menubar icon and menu
    HotkeyManager.swift         # Global hotkey registration
    
    Models/
      AppSettings.swift         # Settings data model
      CustomWord.swift          # Custom word model
      HistoryEntry.swift        # SwiftData history model
    
    Services/
      SettingsManager.swift     # UserDefaults settings
      KeychainService.swift     # Secure API key storage
      LoggingService.swift      # File-based logging
      AXSelectionService.swift  # Accessibility API
      ClipboardService.swift    # Clipboard operations
      LLMClient.swift           # OpenAI API client
      LocalLLMRunner.swift      # Local LLM support
      MaskingService.swift      # Custom word masking
      HistoryStore.swift        # SwiftData operations
      NotificationService.swift # macOS notifications
    
    Flows/
      GrammarCorrectionFlow.swift  # Grammar correction orchestration
      TranslationFlow.swift        # Translation orchestration
    
    Preferences/
      PreferencesView.swift        # Main preferences window
      GeneralSettingsView.swift    # General settings tab
      GrammarSettingsView.swift    # Grammar settings tab
      LLMSettingsView.swift        # LLM settings tab
      CustomWordsView.swift        # Custom words tab
      HistoryView.swift            # History tab
      DebugSettingsView.swift      # Debug settings tab
  
  GrammarPoliceTests/
    MaskingServiceTests.swift      # Masking unit tests
    CSVExportTests.swift           # Export unit tests
    SettingsSerializationTests.swift # Settings tests
```

## Testing

Run the test suite:

```bash
xcodebuild test -project GrammarPolice.xcodeproj -scheme GrammarPolice
```

Or in Xcode: Product > Test (Cmd+U)

## Troubleshooting

### Hotkeys not working

1. Ensure Accessibility permission is granted
2. Check if another app is using the same hotkey
3. Try restarting the app

### Text not being replaced

Some applications (like Google Docs in Chrome) don't support direct text replacement. In these cases:
1. The corrected text will be copied to your clipboard
2. A notification will inform you to paste manually
3. Use Cmd+V to paste the corrected text

### API errors

1. Verify your API key is correct
2. Check your OpenAI account has sufficient credits
3. Try the "Test Connection" button in Preferences

### Debug logging

Enable debug logging to troubleshoot issues:
1. Open Preferences > Debug tab
2. Enable "Debug Logging"
3. View logs in the Debug tab or export them

## Privacy

- Text is only sent to remote LLM services after explicit consent
- API keys are stored securely in the macOS Keychain
- Custom words are masked before sending to prevent accidental modification
- All history is stored locally on your device

## License

[Add your license here]

## Contributing

[Add contribution guidelines here]

