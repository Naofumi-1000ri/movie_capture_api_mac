# MovieCapture 設計書

Mac専用の画面録画CLIツール + MCPサーバー。GUIなし。

## アーキテクチャ

```
  moviecapture (CLI)  │  moviecapture-mcp (MCPサーバー)
        └─────────────┴──────────────────┘
                      │
             CaptureEngine (Swift Package)
              ScreenCaptureKit + AVFoundation
```

### 設計方針

- **CaptureEngine** はSwift Packageライブラリ。CLI/MCPから共通利用
- macOS 15.0+ ターゲット。`SCRecordingOutput` で録画
- ScreenCaptureKitへの依存を **プロトコルで抽象化** しモック可能（TDD）
- 設定は **YAML ファイル** (`~/.moviecapture.yaml`)

## モジュール構成

### CaptureEngine（ライブラリ）

| ファイル | 責務 |
|---|---|
| `ScreenCaptureManager` | `SCShareableContent`列挙 → `AvailableSources`に変換 |
| `RecordingManager` | 録画セッション管理（開始/停止/一時停止） |
| `RecordingConfiguration` | 設定値型 + YAMLシリアライズ + バリデーション |
| `WindowInfo` / `DisplayInfo` | ScreenCaptureKit非依存のモデル型 |
| `CaptureSource` | `.display` / `.window` / `.windowContentOnly` / `.area` |
| `RecordingState` | 状態マシン（idle → preparing → recording → stopping → completed） |
| `CaptureError` | エラー型（日本語メッセージ付き） |

### プロトコル（テスタビリティ）

| プロトコル | 責務 |
|---|---|
| `ScreenCaptureProviding` | ソース列挙の抽象化 |
| `RecordingProviding` | 録画操作の抽象化 |

### CLI（moviecapture）

| コマンド | 説明 |
|---|---|
| `list [displays\|windows\|all]` | キャプチャソース一覧 |
| `record` | 録画実行 |
| `config [show\|create\|path]` | 設定管理 |
| `status` | 録画状態の確認 |
| `stop` | 実行中の録画を停止 |

### 共通フラグ

| フラグ | 説明 |
|---|---|
| `--json` | 機械可読な JSON 形式で出力（list, record, status, stop で利用可能） |

### 主なCLIオプション（record）

```
--display <id>      ディスプレイID指定
--window-id <id>    ウィンドウID指定
--window <title>    ウィンドウタイトル検索
--app <name>        アプリ名検索
--content-only      タイトルバー除外（コンテンツ領域のみ）
--output / -o       出力ファイルパス
--duration          録画秒数（未指定時はCtrl+C or `moviecapture stop` で停止）
--fps               フレームレート
--codec             コーデック (h264, h265)
--format            フォーマット (mov, mp4)
--config            設定ファイルパス
--json              JSON形式で結果を出力
```

### プロセス間制御

別ターミナルからの録画制御は PID ファイル + 状態ファイルで実現:

| ファイル | 用途 |
|---|---|
| `~/.moviecapture.pid` | 録画プロセスの PID |
| `~/.moviecapture.state.json` | 録画状態（ソース名、開始時刻等） |

`record` コマンドが開始時に書き込み、終了時に削除。`status` / `stop` コマンドがこれを参照する。

## ファイル構成

```
MovieCapture/
├── Package.swift
├── Sources/
│   ├── CaptureEngine/
│   │   ├── Models/
│   │   │   ├── WindowInfo.swift
│   │   │   ├── DisplayInfo.swift
│   │   │   ├── CaptureSource.swift
│   │   │   ├── RecordingConfiguration.swift
│   │   │   ├── RecordingState.swift
│   │   │   └── AvailableSources.swift
│   │   ├── Protocols/
│   │   │   ├── ScreenCaptureProviding.swift
│   │   │   └── RecordingProviding.swift
│   │   ├── Errors/
│   │   │   └── CaptureError.swift
│   │   ├── ScreenCaptureManager.swift
│   │   └── RecordingManager.swift
│   └── MovieCaptureCLI/
│       ├── MovieCaptureCLI.swift
│       ├── Commands/
│       │   ├── ListCommand.swift
│       │   ├── RecordCommand.swift
│       │   ├── ConfigCommand.swift
│       │   ├── StatusCommand.swift
│       │   └── StopCommand.swift
│       └── Helpers/
│           ├── PermissionCheck.swift
│           └── ProcessState.swift
├── Tests/
│   ├── CaptureEngineTests/
│   │   ├── Mocks/MockScreenCaptureProvider.swift
│   │   ├── WindowInfoTests.swift
│   │   ├── RecordingConfigurationTests.swift
│   │   ├── RecordingStateTests.swift
│   │   ├── AvailableSourcesTests.swift
│   │   ├── CaptureErrorTests.swift
│   │   ├── RecordingManagerTests.swift
│   │   └── MockScreenCaptureProviderTests.swift
│   └── MovieCaptureCLITests/
│       └── CLITests.swift
└── docs/
    └── DESIGN.md
```

## テスト方針（TDD）

- ScreenCaptureKitを `ScreenCaptureProviding` プロトコルで抽象化
- `MockScreenCaptureProvider` でユニットテスト
- モデル層（WindowInfo, RecordingConfiguration等）は直接テスト
- RecordingManagerの状態遷移・バリデーションはモック経由でテスト
- 実際のScreenCaptureKit統合テストはCI除外の手動テスト

## macOS権限

- `NSScreenCaptureUsageDescription`: 画面収録権限
- `NSMicrophoneUsageDescription`: マイク権限
- ターゲット: macOS 15.0+, Swift 6
- App Sandbox: 無効（開発段階）

## 実装フェーズ

- [x] Phase 1: CaptureEngine基盤 + 最小限CLI + テスト（45テスト通過）
- [ ] Phase 2: 実機統合テスト・録画動作確認
- [x] Phase 3: MCPサーバー
- [x] Phase 3.5: CLI拡充（--json出力、status/stop コマンド、help改善）
- [ ] Phase 4: 品質向上（HDR、カーソルハイライト等）
