import Foundation

enum PermissionCheck {
    /// ScreenCaptureKitの権限エラーかどうかを判定し、ガイドメッセージを表示する
    /// 権限エラーの場合はtrue、それ以外はfalse
    @discardableResult
    static func handleScreenCaptureError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == "com.apple.ScreenCaptureKit.SCStreamErrorDomain" && nsError.code == -3801 {
            print("エラー: 画面収録の権限がありません。")
            print("")
            print("以下の手順で許可してください:")
            print("  1. システム設定 > プライバシーとセキュリティ > 画面収録とシステム音声収録")
            print("  2. お使いのターミナルアプリを許可")
            print("  3. ターミナルを再起動")
            return true
        }
        return false
    }
}
