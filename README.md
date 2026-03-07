# MovieCapture

macOS 画面録画ツール。CLI と MCP サーバーの 2 つのインターフェースを提供し、人間からも AI からも画面録画を制御できる。

## 特徴

- **ディスプレイ録画** - メインディスプレイまたは指定ディスプレイを録画
- **ウィンドウ録画** - アプリ名、ウィンドウタイトル、ウィンドウ ID でターゲットを指定
- **content-only モード** - タイトルバーを除外してウィンドウの中身だけを録画（Chrome 等の Web コンテンツキャプチャに最適）
- **別 Space のウィンドウ対応** - フルスクリーンや他の仮想デスクトップにあるウィンドウも録画可能
- **安全な停止制御** - `--duration` 指定中でも `Ctrl+C` や `moviecapture stop` で破損なく停止
- **MCP サーバー** - AI（Claude Desktop 等）から直接録画を制御

## 動作要件

- macOS 15.0 (Sequoia) 以上
- Xcode 16.2 以上（Swift 6.0）
- 画面収録の権限（初回実行時に許可が必要）

## ビルド

```bash
git clone <repository-url>
cd MovieCapture
swift build
```

## CLI 使い方

### ソース一覧

```bash
# ディスプレイとウィンドウの一覧
moviecapture list

# ウィンドウのみ
moviecapture list windows

# 特定アプリのウィンドウ
moviecapture list --app Chrome

# JSON 形式で出力（AI 連携に便利）
moviecapture list --json
```

### 録画

```bash
# メインディスプレイを録画（Ctrl+C で停止）
moviecapture record

# 5秒間だけ録画（途中で Ctrl+C / moviecapture stop でも安全停止）
moviecapture record --duration 5

# ウィンドウ ID を指定して録画
moviecapture record --window-id 1234

# アプリ名で検索して録画
moviecapture record --app Chrome

# content-only モード（タイトルバー除外）
moviecapture record --app Chrome --content-only

# 出力先・コーデック・フォーマット指定
moviecapture record --output ~/Desktop/demo.mp4 --codec h264 --format mp4 --fps 60

# JSON 形式で結果を出力
moviecapture record --app Chrome --duration 5 --json
# → {"duration":5.02,"file":"/Users/.../MovieCapture_2026-03-04.mov","source":"Google Chrome","status":"completed","stopReason":"duration"}
```

### 録画の制御（別プロセスから）

```bash
# バックグラウンドで録画開始
moviecapture record --app Chrome &

# 別ターミナルから状態確認
moviecapture status
moviecapture status --json
# → {"elapsed":1.23,"outputPath":"/Users/.../Movies/MovieCapture_....mov","pid":12345,"source":"Google Chrome","status":"recording"}

# 別ターミナルから停止
moviecapture stop
```

### 設定

```bash
# 現在の設定を表示
moviecapture config show

# 現在の設定を JSON で表示
moviecapture config show --json

# 設定ファイルを初期化（~/.moviecapture.yaml）
moviecapture config create

# 既存設定を明示的に上書き
moviecapture config create --force --json
```

### JSON 出力（`--json` フラグ）

すべてのコマンドで `--json` フラグが利用可能。AI やスクリプトからのパースに適した出力を得られる。

```bash
# ソース一覧を JSON で取得 → ウィンドウ ID を抽出 → 録画
WINDOW_ID=$(moviecapture list --json | python3 -c "import sys,json; print(json.load(sys.stdin)['windows'][0]['id'])")
moviecapture record --window-id $WINDOW_ID --duration 5 --json
```

## MCP サーバー（AI 連携）

### セットアップ

1. ビルド:
   ```bash
   swift build
   ```

2. Claude Desktop の設定ファイルに追加:
   ```bash
   # macOS
   vim ~/Library/Application\ Support/Claude/claude_desktop_config.json
   ```

   ```json
   {
     "mcpServers": {
       "moviecapture": {
         "command": "/path/to/MovieCapture/.build/arm64-apple-macosx/debug/moviecapture-mcp"
       }
     }
   }
   ```

3. Claude Desktop を再起動

4. 初回実行時に画面収録の権限ダイアログが表示されるので許可

### MCP ツール

| ツール | 説明 |
|--------|------|
| `list_sources` | 録画可能なディスプレイ・ウィンドウ一覧を JSON で取得 |
| `resolve_target` | app / window / ID 指定を一意解決し、曖昧時は候補一覧を JSON で返す |
| `capture_still` | 対象の静止画プレビューを JSON + PNG image content で返す。JSON には OCR と target metadata を併用した `preview_match_status`、`matched_query_terms_in_target_metadata`、`recognized_text`、`dominant_colors` を含む |
| `start_recording` | 録画開始。曖昧一致では録画せず error JSON を返す。preview 未確認や weak match の場合は advisory を返す |
| `stop_recording` | 録画停止。保存先と停止理由を JSON で返す |
| `get_status` | 現在の録画状態を JSON で確認 |

### AI 推奨フロー

AI が意図通りに録画するには、次の順で呼ぶのが安全:

1. `list_sources` で候補一覧を取得
2. `resolve_target` で対象を一意解決
3. `capture_still` で静止画プレビューと preview metadata を取得して対象確認
   `app` / `window` を使っている場合は、同じ selector を `capture_still` にも渡すと `preview_match_status` を使いやすい
4. `start_recording` を `display_id` または `window_id` で実行
   直前 preview が未確認または弱い場合は `advisories` に warning が入る
5. 必要に応じて `get_status` / `stop_recording`

### AI からの使用例

```
「Chrome の Proposal ウィンドウだけを 10 秒録画して」
→ AI が list_sources
→ resolve_target(app="Chrome", window="Proposal", content_only=true)
→ capture_still(app="Chrome", window="Proposal", content_only=true)
→ start_recording(window_id=..., content_only=true, duration=10)
```

## 権限設定

初回実行時に macOS の「画面収録」権限が必要。

1. システム設定 → プライバシーとセキュリティ → 画面収録
2. ターミナル（CLI の場合）または `moviecapture-mcp`（MCP の場合）を許可

CLI と MCP サーバーは別バイナリのため、それぞれ個別に許可が必要。

## テスト

```bash
swift test
```

63 テスト（モデル / 設定 / 状態管理 / ストリーム構成 / エラーハンドリング / CLI バリデーション / MCP ターゲット解決 / preview 分析 / advisory 判定）

### 手動スモークテスト

画面収録権限がある実機では、MCP 経由の自己キャプチャを次で確認できる:

```bash
python3 scripts/mcp_capture_smoke.py
```

このスクリプトは専用の Swift/AppKit fixture ウィンドウを開き、`list_sources -> resolve_target -> capture_still -> start_recording -> get_status` を実行して、preview 一致判定と録画ファイル生成まで確認する。さらに出力動画から静止フレームを取り出し、fixture 固有色が含まれていることも検証する。AppleScript や既存アプリ操作には依存しない。

## プロジェクト構成

```
MovieCapture/
├── Package.swift
├── Sources/
│   ├── CaptureEngine/          # コアライブラリ
│   │   ├── Models/             # WindowInfo, DisplayInfo, CaptureSource, etc.
│   │   ├── Protocols/          # ScreenCaptureProviding（テスト用抽象化）
│   │   ├── Errors/             # CaptureError
│   │   ├── CaptureSourceSetup.swift   # 録画/静止画キャプチャ用の共通 filter / geometry 構築
│   │   ├── RecordingManager.swift    # 録画エンジン
│   │   ├── ScreenCaptureManager.swift # ScreenCaptureKit ラッパー
│   │   └── AppInitializer.swift      # CGS セッション初期化
│   ├── MovieCaptureCLI/        # CLI アプリ
│   │   ├── Commands/           # list, record, config, status, stop サブコマンド
│   │   └── Helpers/            # 権限チェック、プロセス状態管理
│   └── MovieCaptureMCP/        # MCP サーバー
│       └── Tools/              # ツール定義、ハンドラー
├── Tests/
│   ├── CaptureEngineTests/     # ユニットテスト + モック
│   ├── MovieCaptureCLITests/
│   │   └── CLITests.swift
│   └── MovieCaptureMCPTests/
│       ├── TargetResolverTests.swift
│       ├── StillImageAnalyzerTests.swift
│       └── StartRecordingAdvisoriesTests.swift
├── scripts/
│   ├── capture_fixture.swift   # 手動E2E用 fixture ウィンドウ
│   ├── mcp_capture_smoke.py    # MCP 経由の自己キャプチャスモーク
│   └── verify_capture_frame.swift # 録画フレーム検証
└── docs/
    └── DESIGN.md               # 設計ドキュメント
```

## 技術スタック

- **ScreenCaptureKit** (macOS 15+) - 画面キャプチャ API
- **SCRecordingOutput** - ファイルベース録画
- **Swift Argument Parser** - CLI フレームワーク
- **MCP Swift SDK 0.9.0** - Model Context Protocol サーバー
- **Yams** - YAML 設定ファイル

## ライセンス

[MIT License](LICENSE)
