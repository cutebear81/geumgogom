import Foundation

/// 한글 검색 도우미.
/// 한 글자 칠 때마다 후보를 좁히는 용도라, **부분일치**와 **초성검색**을 함께 지원한다.
enum KoreanSearch {
    private static let choseong = Array("ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ")

    /// "국민은행" → "ㄱㅁㅇㅎ" (한글이 아닌 글자는 그대로 둔다)
    static func initials(of text: String) -> String {
        var out = ""
        for ch in text {
            guard let scalar = ch.unicodeScalars.first?.value,
                  (0xAC00...0xD7A3).contains(scalar) else {
                out.append(ch)
                continue
            }
            out.append(choseong[Int((scalar - 0xAC00) / 588)])
        }
        return out
    }

    /// 입력이 초성만으로 이뤄졌는지 (ㄱㅁ 처럼)
    static func isInitialsOnly(_ text: String) -> Bool {
        !text.isEmpty && text.allSatisfy { choseong.contains($0) }
    }

    /// 후보 이름이 검색어에 걸리는지.
    /// - 초성만 쳤으면 초성열로, 아니면 이름·별칭 부분일치로 본다.
    static func matches(_ name: String, aliases: [String] = [], query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return true }

        if isInitialsOnly(q) {
            return initials(of: name).contains(q)
                || aliases.contains { initials(of: $0).contains(q) }
        }
        let lowered = q.lowercased()
        return name.lowercased().contains(lowered)
            || aliases.contains { $0.lowercased().contains(lowered) }
    }
}
