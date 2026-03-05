# MovieCapture - プロジェクト固有の指示

日本語で応答すること。

## プロジェクト概要

macOS 画面録画ツール。CLI (`moviecapture`) と MCP サーバー (`moviecapture-mcp`) の 2 つのインターフェースを提供。

## 開発コマンド

```bash
swift build          # ビルド
swift test           # テスト実行（47テスト）
```

## 作業前に読むもの

- `.claude/commands/work-rules.md` — 開発ルール・コーディング規約
- `.claude/commands/capture.md` — CLI の使い方（AI が録画するとき用）
- `.claude/commands/build.md` — ビルド・テストの手順
- `docs/DESIGN.md` — アーキテクチャ・モジュール構成

## 重要な規約

- CLI コマンドには必ず `--json` フラグを付ける
- `--help` の `discussion` を充実させる（AI が読んで理解できるように）
- ScreenCaptureKit への依存は CaptureEngine 内に閉じる
- 変更後は `swift build` → `swift test` を実行して確認する
- コード変更時は `README.md` と `docs/DESIGN.md` も更新する
