---
description: プロジェクトのビルドとテストを実行する
---

# ビルド・テスト

## ビルド

```bash
swift build
```

成功時: `Build complete!` と表示される。

## テスト

```bash
swift test
```

- CaptureEngine のユニットテスト（モデル・状態管理・バリデーション等）
- CLI のビルド確認テスト
- ScreenCaptureKit を使う統合テストは CI 除外（実機のみ）

## 実機での動作確認

```bash
# ソース一覧
.build/debug/moviecapture list --json | python3 -m json.tool

# 短時間の録画テスト
.build/debug/moviecapture record --duration 3 --json | python3 -m json.tool

# status/stop テスト
.build/debug/moviecapture record --duration 30 &
.build/debug/moviecapture status --json
.build/debug/moviecapture stop --json
```
