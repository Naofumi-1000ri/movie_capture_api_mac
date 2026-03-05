---
description: このプロジェクトでの開発ルールと規約
---

# MovieCapture 開発ルール

## アーキテクチャ

```
moviecapture (CLI)  │  moviecapture-mcp (MCPサーバー)
      └─────────────┴──────────────────┘
                    │
           CaptureEngine (ライブラリ)
```

- **CaptureEngine**: コアロジック。CLI/MCP 両方から使う共通ライブラリ
- **MovieCaptureCLI**: 人間 & AI 向けの CLI（`--json` で機械可読出力）
- **MovieCaptureMCP**: Claude Desktop 向け MCP サーバー

## コーディング規約

- Swift 6.0 / macOS 15.0+
- `Sendable` 準拠を意識する
- ScreenCaptureKit への直接依存は CaptureEngine 内に閉じる
- テスタビリティのため `ScreenCaptureProviding` プロトコルで抽象化

## ファイル配置

| 種別 | パス |
|------|------|
| モデル型 | `Sources/CaptureEngine/Models/` |
| プロトコル | `Sources/CaptureEngine/Protocols/` |
| エラー型 | `Sources/CaptureEngine/Errors/` |
| CLI コマンド | `Sources/MovieCaptureCLI/Commands/` |
| CLI ヘルパー | `Sources/MovieCaptureCLI/Helpers/` |
| MCP ツール | `Sources/MovieCaptureMCP/Tools/` |
| テスト | `Tests/CaptureEngineTests/` |
| モック | `Tests/CaptureEngineTests/Mocks/` |

## CLI コマンド追加時のルール

1. `Sources/MovieCaptureCLI/Commands/` に `XxxCommand.swift` を作成
2. `AsyncParsableCommand` に準拠
3. `--json` フラグを必ず付ける（AI フレンドリー）
4. `configuration` に `discussion` を書き、`--help` だけで使い方が分かるようにする
5. `MovieCaptureCLI.swift` の `subcommands` に登録
6. JSON 出力は `JSONSerialization` で生成（`sortedKeys` オプション付き）

## テスト方針

- モデル層は直接テスト
- RecordingManager は `MockScreenCaptureProvider` 経由でテスト
- CLI の統合テストは実機のみ（ScreenCaptureKit 権限が必要）
- 変更後は `swift build` → `swift test` を必ず実行

## ドキュメント更新

コードを変更したら以下も更新する:
- `README.md` — ユーザー向け使い方
- `docs/DESIGN.md` — 設計情報・ファイル構成
