# QuotaLens

QuotaLens is an iOS app prototype for monitoring AI subscription quota usage across providers such as Codex, Claude, ChatGPT, Gemini, Cursor, Perplexity, and Poe.

The app is built with SwiftUI and UIKit on iOS 26, including a custom UIKit bottom dock that preserves native Liquid Glass behavior while keeping separate add and refresh actions.

## Current Highlights

- Native iOS app shell with Today, Insights, and Settings tabs.
- Real-data-first dashboard states without fake quota samples.
- Local OAuth/token storage architecture for provider quota sync.
- Codex quota parsing with Pro 5x / Pro 20x distinction and Spark window support.
- File import flow for Codex auth JSON.
- Focused unit coverage for quota models, native OAuth, token storage, dashboard state, and visible UI guardrails.

## Development

Generate or refresh the Xcode project from `project.yml` when source groups change:

```sh
xcodegen generate
```

Run the iOS test suite from Xcode, or with an iOS simulator target via `xcodebuild`.

## Security

This repository intentionally does not include local tokens, imported auth files, build artifacts, or OAuth client secrets. Runtime credentials should stay on-device and out of source control.
