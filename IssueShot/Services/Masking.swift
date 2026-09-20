import Foundation

/// トークン・JWT・認証ヘッダー・メールアドレスなど、よくある秘匿情報を伏せ字にする
enum Masking {
    private static let patterns: [(regex: NSRegularExpression, replacement: String)] = [
        (try! NSRegularExpression(pattern: #"Authorization:\s*Bearer\s+[^\s]+"#, options: .caseInsensitive), "Authorization: Bearer [MASKED]"),
        (try! NSRegularExpression(pattern: #"Cookie:\s*[^\n]+"#, options: .caseInsensitive), "Cookie: [MASKED]"),
        (try! NSRegularExpression(pattern: #"eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"#), "[MASKED_JWT]"),
        (try! NSRegularExpression(pattern: #"\b(gh[opsu]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})\b"#), "[MASKED_TOKEN]"),
        (try! NSRegularExpression(pattern: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#), "[MASKED_EMAIL]"),
    ]

    static func mask(_ text: String) -> String {
        patterns.reduce(text) { current, entry in
            entry.regex.stringByReplacingMatches(
                in: current,
                range: NSRange(current.startIndex..., in: current),
                withTemplate: entry.replacement
            )
        }
    }
}
