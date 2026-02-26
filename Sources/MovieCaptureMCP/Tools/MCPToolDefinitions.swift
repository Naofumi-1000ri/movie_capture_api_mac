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
        description: "利用可能なキャプチャソース（ディスプレイ・ウィンドウ）を一覧表示",
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
                    "description": .string("アプリ名でウィンドウをフィルタ"),
                ]),
                "on_screen_only": .object([
                    "type": .string("boolean"),
                    "description": .string("オンスクリーンのウィンドウのみ表示（デフォルト: true）"),
                ]),
            ]),
        ])
    )

    static let startRecordingTool = Tool(
        name: "start_recording",
        description: "画面録画を開始。ウィンドウID、アプリ名、ウィンドウタイトルで対象を指定可能。content_onlyでタイトルバーを除外",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "window_id": .object([
                    "type": .string("integer"),
                    "description": .string("ウィンドウIDを指定して録画"),
                ]),
                "app": .object([
                    "type": .string("string"),
                    "description": .string("アプリ名で検索して録画"),
                ]),
                "window": .object([
                    "type": .string("string"),
                    "description": .string("ウィンドウタイトルで検索して録画"),
                ]),
                "content_only": .object([
                    "type": .string("boolean"),
                    "description": .string("タイトルバーを除いたコンテンツ領域のみ録画（デフォルト: false）"),
                ]),
                "duration": .object([
                    "type": .string("integer"),
                    "description": .string("録画時間（秒）。省略時はstop_recordingで停止"),
                ]),
                "fps": .object([
                    "type": .string("integer"),
                    "description": .string("フレームレート（デフォルト: 30）"),
                ]),
                "codec": .object([
                    "type": .string("string"),
                    "enum": .array([.string("h264"), .string("h265")]),
                    "description": .string("コーデック（デフォルト: h265）"),
                ]),
                "format": .object([
                    "type": .string("string"),
                    "enum": .array([.string("mov"), .string("mp4")]),
                    "description": .string("ファイルフォーマット（デフォルト: mov）"),
                ]),
                "output": .object([
                    "type": .string("string"),
                    "description": .string("出力ファイルパス（デフォルト: ~/Movies/）"),
                ]),
            ]),
        ])
    )

    static let stopRecordingTool = Tool(
        name: "stop_recording",
        description: "録画を停止して保存。出力ファイルパスを返す",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:]),
        ])
    )

    static let getStatusTool = Tool(
        name: "get_status",
        description: "現在の録画状態を取得",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:]),
        ])
    )
}
