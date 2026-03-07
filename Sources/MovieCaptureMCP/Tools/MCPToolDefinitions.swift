import MCP

enum MCPToolDefinitions {
    static let allTools: [Tool] = [
        listSourcesTool,
        resolveTargetTool,
        captureStillTool,
        startRecordingTool,
        stopRecordingTool,
        getStatusTool,
    ]

    static let listSourcesTool = Tool(
        name: "list_sources",
        description: """
            利用可能なキャプチャソースを JSON で返す。\
            displays / windows 配列には ID・サイズ・座標・owner_name・title などが含まれる。\
            AI はまずこれを呼んで候補を把握し、必要なら resolve_target で一意解決してから start_recording を呼ぶこと。\
            app 指定時は windows 配列のみ返す。
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

    static let resolveTargetTool = Tool(
        name: "resolve_target",
        description: """
            録画対象を一意に解決して JSON で返す。\
            status は resolved / ambiguous / not_found のいずれか。\
            app や window で曖昧一致した場合は candidates 配列を返し、録画は開始しない。\
            start_recording 前の確認ステップとして使うこと。
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "display_id": .object([
                    "type": .string("integer"),
                    "description": .string("対象ディスプレイID"),
                ]),
                "window_id": .object([
                    "type": .string("integer"),
                    "description": .string("対象ウィンドウID"),
                ]),
                "app": .object([
                    "type": .string("string"),
                    "description": .string("アプリ名部分一致。window と同時指定するとAND条件で絞り込む"),
                ]),
                "window": .object([
                    "type": .string("string"),
                    "description": .string("ウィンドウタイトル部分一致。app と同時指定するとAND条件で絞り込む"),
                ]),
                "content_only": .object([
                    "type": .string("boolean"),
                    "description": .string("ウィンドウのコンテンツ領域のみ録画する前提で解決する"),
                ]),
                "on_screen_only": .object([
                    "type": .string("boolean"),
                    "description": .string("オンスクリーンのウィンドウだけを候補にする（デフォルト: true）"),
                ]),
            ]),
        ])
    )

    static let startRecordingTool = Tool(
        name: "start_recording",
        description: """
            画面録画を開始し、結果を JSON で返す。\
            app / window を使う場合は内部で一意解決を試み、曖昧一致なら error + candidates を返して録画しない。\
            確実性が必要なら resolve_target を先に呼び、その結果の display_id / window_id を使うこと。\
            直前の capture_still が未確認または weak match の場合でも録画は開始するが、advisories に warning を返す。\
            対象未指定時はメインディスプレイを録画する。\
            録画停止は stop_recording を呼ぶか、duration で自動停止時間を指定。
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "display_id": .object([
                    "type": .string("integer"),
                    "description": .string("録画対象のディスプレイID（list_sources で取得）。省略時はメインディスプレイ"),
                ]),
                "window_id": .object([
                    "type": .string("integer"),
                    "description": .string("録画対象のウィンドウID（list_sources で取得）"),
                ]),
                "app": .object([
                    "type": .string("string"),
                    "description": .string("アプリ名部分一致。window と同時指定するとAND条件で絞り込む"),
                ]),
                "window": .object([
                    "type": .string("string"),
                    "description": .string("ウィンドウタイトル部分一致。app と同時指定するとAND条件で絞り込む"),
                ]),
                "content_only": .object([
                    "type": .string("boolean"),
                    "description": .string("タイトルバーを除いたコンテンツ領域のみ録画（デフォルト: false）"),
                ]),
                "on_screen_only": .object([
                    "type": .string("boolean"),
                    "description": .string("オンスクリーンのウィンドウだけを候補にする（デフォルト: true）"),
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

    static let captureStillTool = Tool(
        name: "capture_still",
        description: """
            指定対象の静止画プレビューを取得し、JSON と PNG image content を返す。\
            app / window を使う場合は内部で一意解決を試み、曖昧一致なら error + candidates を返して静止画を返さない。\
            AI は resolve_target の直後にこれを呼び、対象が合っていることを視覚確認してから start_recording を呼ぶと安全。\
            max_dimension で長辺を制限できる。
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "display_id": .object([
                    "type": .string("integer"),
                    "description": .string("対象ディスプレイID"),
                ]),
                "window_id": .object([
                    "type": .string("integer"),
                    "description": .string("対象ウィンドウID"),
                ]),
                "app": .object([
                    "type": .string("string"),
                    "description": .string("アプリ名部分一致。window と同時指定するとAND条件で絞り込む"),
                ]),
                "window": .object([
                    "type": .string("string"),
                    "description": .string("ウィンドウタイトル部分一致。app と同時指定するとAND条件で絞り込む"),
                ]),
                "content_only": .object([
                    "type": .string("boolean"),
                    "description": .string("ウィンドウのコンテンツ領域のみ静止画化する"),
                ]),
                "on_screen_only": .object([
                    "type": .string("boolean"),
                    "description": .string("オンスクリーンのウィンドウだけを候補にする（デフォルト: true）"),
                ]),
                "max_dimension": .object([
                    "type": .string("integer"),
                    "description": .string("出力画像の長辺上限。デフォルト: 1200"),
                ]),
            ]),
        ])
    )

    static let stopRecordingTool = Tool(
        name: "stop_recording",
        description: "進行中の録画を停止して保存し、output_path などを JSON で返す。録画中でない場合は error JSON を返す",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:]),
        ])
    )

    static let getStatusTool = Tool(
        name: "get_status",
        description: """
            現在の録画状態を JSON で取得。\
            status は idle / preparing / recording / paused / stopping / completed / failed。\
            可能な場合は output_path, elapsed_seconds, target も返す。
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:]),
        ])
    )
}
