import Foundation

/// アプリに同梱する GitHub OAuth App の設定。
/// 誰でも「GitHub と連携」を押すだけで使えるように、Client ID はビルドに含める
/// （Device Flow は client secret を使わないので公開しても問題ない）。
enum OAuthConfig {
    /// GitHub > Settings > Developer settings > OAuth Apps で作成し、
    /// 「Enable Device Flow」を有効にした OAuth App の Client ID。
    static let bundledClientID = "Ov23li1Ika5wnsCGUxcD"

    /// 設定画面での上書き > 同梱値 の順に解決する
    static func resolveClientID(override: String?) -> String {
        let trimmed = override?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? bundledClientID : trimmed
    }
}
