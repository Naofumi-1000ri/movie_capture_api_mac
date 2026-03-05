---
description: moviecapture CLI で画面を録画する。ソース一覧取得→録画→結果確認の一連の流れ。
---

# 画面録画ワークフロー

moviecapture CLI を使って画面を録画する手順。
すべてのコマンドで `--json` フラグを付けて JSON 出力を使うこと。

## 1. ソース一覧を取得

```bash
moviecapture list --json
```

出力例:
```json
{"displays":[{"id":1,"width":1800,"height":1169}],"windows":[{"id":26209,"app":"Google Chrome","title":"GitHub","width":1704,"height":1003,"onScreen":true}]}
```

特定アプリのウィンドウだけ取得:
```bash
moviecapture list --app Chrome --json
```

## 2. 録画を実行

ウィンドウ ID 指定（最も確実）:
```bash
moviecapture record --window-id <ID> --duration <秒> --json
```

アプリ名指定（簡易）:
```bash
moviecapture record --app <アプリ名> --duration <秒> --json
```

出力例:
```json
{"duration":5.02,"file":"/Users/.../MovieCapture_2026-03-04.mov","source":"Google Chrome","status":"completed"}
```

## 3. 長時間録画の制御

duration を指定しない場合、別ターミナルから制御する:
```bash
# 録画開始（バックグラウンド）
moviecapture record --app Chrome &

# 状態確認
moviecapture status --json

# 停止
moviecapture stop --json
```

## 注意事項

- 初回実行時に macOS の画面収録権限が必要
- `--json` の結果は必ず JSON パースして使う（テキスト出力をパースしない）
- `--content-only` フラグでタイトルバーを除外できる（Web コンテンツのキャプチャに便利）
- 出力ファイルパスは JSON の `file` フィールドから取得する
