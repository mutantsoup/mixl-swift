# Contributing to Mixl

Thank you for your interest in contributing to **Mixl** (`mixl-swift`).

## Getting Started

1. Clone the repository and open it in Xcode or run commands from the package root.
2. Run the test suite before opening a pull request:

   ```bash
   swift test
   ```

3. Optionally run the examples app with a live API key (uses the free `qwen/qwen3.5-4b-free` model):

   ```bash
   export MIXLAYER_API_KEY="your-api-key"
   swift run MixlExamples
   ```

## Development Guidelines

Please read [AGENTS.md](AGENTS.md) before making changes. It documents the project's architecture, Swift conventions, and the mock/production sync rules.

Key expectations:

- Keep `MixlService`, `MixLayerAPIService`, `LocalInferenceService`, and `MockMixlService` in sync.
- Follow naming conventions: **`Mixl*`** (framework shared), **`MixLayer*`** (cloud), **`Local*`** (on-device). See [AGENTS.md](AGENTS.md#ag-sync).
- Use `async/await`; do not add completion-handler APIs.
- Throw typed `MixlError` values from networking code.
- Add or update tests when changing request mappings or response models.
- Only expose request parameters that are documented as supported by [MixLayer](https://docs.mixlayer.com/chat-completions).

## Pull Requests

- Keep changes focused and include tests where behavior changes.
- Update [CHANGELOG.md](CHANGELOG.md) for user-visible changes.
- Ensure CI passes (`swift test` on macOS).

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
