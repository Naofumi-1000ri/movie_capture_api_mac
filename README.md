# MovieCapture

macOS 画面録画ツール。CLI と MCP サーバーの 2 つのインターフェースを提供し、人間からも AI からも画面録画を制御できる。

## 特徴

- **ディスプレイ録画** - メインディスプレイまたは指定ディスプレイを録画
- **ウィンドウ録画** - アプリ名、ウィンドウタイトル、ウィンドウ ID でターゲットを指定
- **content-only モード** - タイトルバーを除外してウィンドウの中身だけを録画（Chrome 等の Web コンテンツキャプチャに最適）
- **別 Space のウィンドウ対応** - フルスクリーンや他の仮想デスクトップにあるウィンドウも録画可能
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

# 5秒間だけ録画
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
# → {"duration":5.02,"file":"/Users/.../MovieCapture_2026-03-04.mov","source":"Google Chrome","status":"completed"}
```

### 録画の制御（別プロセスから）

```bash
# バックグラウンドで録画開始
moviecapture record --app Chrome &

# 別ターミナルから状態確認
moviecapture status
moviecapture status --json

# 別ターミナルから停止
moviecapture stop
```

### 設定

```bash
# 現在の設定を表示
moviecapture config show

# 設定ファイルを初期化（~/.moviecapture.yaml）
moviecapture config create
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
| `list_sources` | 録画可能なディスプレイ・ウィンドウの一覧を取得 |
| `start_recording` | 録画を開始（ディスプレイ / ウィンドウ / content-only） |
| `stop_recording` | 録画を停止してファイルを保存 |
| `get_status` | 現在の録画状態を確認 |

### AI からの使用例

```
「Chrome のウィンドウを content-only で 10 秒間録画して」
→ AI が list_sources → start_recording(app="Chrome", content_only=true, duration=10) を実行
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

47 テスト（モデル / 設定 / 状態管理 / ストリーム構成 / エラーハンドリング）

## プロジェクト構成

```
MovieCapture/
├── Package.swift
├── Sources/
│   ├── CaptureEngine/          # コアライブラリ
│   │   ├── Models/             # WindowInfo, DisplayInfo, CaptureSource, etc.
│   │   ├── Protocols/          # ScreenCaptureProviding（テスト用抽象化）
│   │   ├── Errors/             # CaptureError
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
│   └── MovieCaptureCLITests/
└── docs/
    └── DESIGN.md               # 設計ドキュメント
```

## 技術スタック

- **ScreenCaptureKit** (macOS 15+) - 画面キャプチャ API
- **SCRecordingOutput** - ファイルベース録画
- **Swift Argument Parser** - CLI フレームワーク
- **MCP Swift SDK 0.9.0** - Model Context Protocol サーバー
- **Yams** - YAML 設定ファイル
