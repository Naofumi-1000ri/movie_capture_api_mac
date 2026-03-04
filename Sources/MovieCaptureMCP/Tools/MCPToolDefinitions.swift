import MCP

enum MCPToolDefinitions {
    static let allTools: [Tool] = [
        listSourcesTool,
        startRecordingTool,
        stopRecordingTool,
        getStatusTool,
    ]

    static let listSourcesTool = Tool(
        name: "list_sources",
        description: """
            利用可能なキャプチャソース（ディスプレイ・ウィンドウ）を一覧表示。\
            録画対象を選ぶために最初に呼び出してください。\
            各ウィンドウは "Window ID: <数値>" で表示され、start_recording の window_id に指定できます。\
            app パラメータ指定時はウィンドウのみ表示。\
            出力例: "- Window ID: 1234, [Chrome] Google, 1920x1080, onscreen"
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "type": .object([
                    "type": .string("string"),
                    "enum": .array([.string("displays"), .string("windows")]),
                    "description": .string("表示するソース種別。省略時は両方表示"),
                ]),
                "app": .object([
                    "type": .string("string"),
                    "description": .string("アプリ名でウィンドウをフィルタ（例: 'Chrome', 'Safari'）"),
                ]),
                "on_screen_only": .object([
                    "type": .string("boolean"),
                    "description": .string("オンスクリーンのウィンドウのみ表示（デフォルト: true）。他のSpaceにあるウィンドウも取得するにはfalseを指定"),
                ]),
            ]),
        ])
    )

    static let startRecordingTool = Tool(
        name: "start_recording",
        description: """
            画面録画を開始。対象を指定しない場合はメインディスプレイ全体を録画。\
            ウィンドウを録画するには、まず list_sources で ID を確認し window_id を指定。\
            content_only=true でタイトルバーを除外したウィンドウ内容のみ録画可能。\
            録画停止は stop_recording を呼ぶか、duration で自動停止時間を指定。
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "window_id": .object([
                    "type": .string("integer"),
                    "description": .string("録画対象のウィンドウID（list_sources で取得）"),
                ]),
                "app": .object([
                    "type": .string("string"),
                    "description": .string("アプリ名で最前面ウィンドウを検索して録画（例: 'Chrome'）"),
                ]),
                "window": .object([
                    "type": .string("string"),
                    "description": .string("ウィンドウタイトルの部分一致で検索して録画"),
                ]),
                "content_only": .object([
                    "type": .string("boolean"),
                    "description": .string("タイトルバーを除いたコンテンツ領域のみ録画（デフォルト: false）"),
                ]),
                "duration": .object([
                    "type": .string("integer"),
                    "description": .string("録画時間（秒）。指定すると自動停止。省略時は stop_recording で手動停止"),
                ]),
                "fps": .object([
                    "type": .string("integer"),
                    "description": .string("フレームレート（デフォルト: 30）"),
                ]),
                "codec": .object([
                    "type": .string("string"),
                    "enum": .array([.string("h264"), .string("h265")]),
                    "description": .string("映像コーデック（デフォルト: h265）"),
                ]),
                "format": .object([
                    "type": .string("string"),
                    "enum": .array([.string("mov"), .string("mp4")]),
                    "description": .string("ファイルフォーマット（デフォルト: mov）"),
                ]),
                "output": .object([
                    "type": .string("string"),
                    "description": .string("出力ファイルパス（デフォルト: ~/Movies/recording_<timestamp>.mov）"),
                ]),
            ]),
        ])
    )

    static let stopRecordingTool = Tool(
        name: "stop_recording",
        description: "進行中の録画を停止して保存。保存先ファイルパスを返す。録画中でない場合はエラー",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:]),
        ])
    )

    static let getStatusTool = Tool(
        name: "get_status",
        description: """
            現在の録画状態を取得。状態: 待機中 / 準備中 / 録画中（経過時間付き） / 一時停止 / 停止処理中 / 完了 / エラー
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:]),
        ])
    )
}
