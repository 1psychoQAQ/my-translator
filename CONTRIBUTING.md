# Contributing

Thank you for your interest in contributing to Translator!

## Development Setup

### Prerequisites

- macOS 15.0+ (Sequoia)
- Xcode 16.0+
- Node.js 18+
- Swift 6.0+

### Getting Started

1. Fork and clone the repository
2. Follow the [Building from Source](README.md#building-from-source) instructions

## Code Style

### Swift (macOS)

- Follow Apple's Swift API Design Guidelines
- Use SwiftLint (if configured)
- Prefer protocol-based design for testability

### TypeScript (Chrome Extension)

- ESLint configuration is provided
- Run `npm run lint` before committing
- Run `npm run typecheck` to verify types

## Testing

### Before Submitting a PR

```bash
# Chrome Extension
cd ChromeExtension
npm run test
npm run lint
npm run typecheck

# macOS App
xcodebuild test -project TranslatorApp/TranslatorApp.xcodeproj -scheme TranslatorApp
```

All tests must pass before merging.

## Pull Request Process

1. Create a feature branch from `main`
2. Make your changes
3. Ensure all tests pass
4. Update documentation if needed
5. Submit a pull request

### PR Title Format

- `feat: Add new feature`
- `fix: Fix bug description`
- `docs: Update documentation`
- `refactor: Refactor code`
- `test: Add tests`
- `chore: Maintenance tasks`

## Architecture Guidelines

### Single Responsibility

Each module should do one thing:
- Translation: `translate(text) -> String`
- OCR: `extractText(image) -> String`
- Storage: `save(word)` / `fetch()`

### Dependency Injection

- macOS: Protocol + constructor injection
- Chrome: Interface + factory functions

### Error Handling

- All errors must be explicit
- No silent failures
- User-facing errors need friendly messages

## Questions?

Feel free to open an issue for questions or discussions.
