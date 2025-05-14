# AiApiAccesser

A native macOS application that provides a unified interface to multiple large language model (LLM) APIs including:

- OpenAI ChatGPT
- Anthropic Claude
- DeepSeek

## Features

- Dark mode interface with browser-like tabs for managing multiple conversations
- Support for document processing (PDF, code files, CSV, images)
- Non-streaming responses (complete responses rather than incremental output)
- Local storage of conversation history
- API key management
- Customizable model settings

## Requirements

- macOS 11.0 or later
- Xcode 13.0 or later (for building)
- API keys for the LLMs you wish to use

## Installation

### From Source

1. Clone the repository
git clone https://github.com/yourusername/AiApiAccesser.git

2. Open the project in Xcode
cd AiApiAccesser
open AiApiAccesser.xcodeproj

3. Build and run the application

### Binary Release

Download the latest release from the [Releases](https://github.com/yourusername/AiApiAccesser/releases) page.

## Usage

1. Launch the application
2. Go to Settings > API Management to add your API keys
3. Create a new conversation by clicking the "+" button in the tab bar
4. Select the model you wish to use
5. Optionally attach documents using the paperclip icon
6. Type your message and press Enter or click the send button

## Security

API keys are stored securely in the macOS Keychain.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.