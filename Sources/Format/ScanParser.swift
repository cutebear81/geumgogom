import Foundation

/// 촬영한 이미지에서 뽑아낸 텍스트를 카테고리별 필드로 갈라내는 순수 로직.
/// OCR은 흔히 잘못 읽으므로, **확실한 것만 채우고 나머지는 사용자가 고치게** 한다.
enum ScanParser {

    // MARK: 카드

    static func parseCard(lines: [String], text: String) -> [String: String] {
        var out: [String: String] = [:]

        // 숫자 덩어리를 이어붙여 카드번호 후보를 만든다. Luhn을 통과한 것만 채택한다.
        for line in lines {
            let digits = line.filter(\.isNumber)
            guard (13...19).contains(digits.count), CardFormat.isLuhnValid(digits) else { continue }
            out["number"] = digits
            break
        }

        if let expiry = firstMatch(#"\b(0[1-9]|1[0-2])\s*/\s*([0-9]{2})\b"#, in: text) {
            out["expiry"] = expiry.replacingOccurrences(of: " ", with: "")
        }
        return out
    }

    // MARK: 계좌
    // 계좌번호는 검증할 방법이 없어서, 하이픈이 섞인 숫자 줄 중 가장 그럴듯한 것을 고른다.

    static func parseAccount(lines: [String]) -> [String: String] {
        var out: [String: String] = [:]
        var best: String?
        for line in lines {
            let compact = line.filter { $0.isNumber || $0 == "-" }
            let digits = compact.filter(\.isNumber)
            guard (10...14).contains(digits.count) else { continue }
            // 카드번호로 보이는 건 계좌에서 제외한다
            if CardFormat.isLuhnValid(digits) && digits.count >= 13 { continue }
            if best == nil || digits.count > (best?.count ?? 0) { best = digits }
        }
        if let best { out["number"] = best }

        // 통장에 은행 이름이 찍혀 있으면 같이 잡아준다
        outer: for line in lines {
            for bank in Institutions.banks {
                for token in [bank.name] + bank.aliases where token.count >= 2 && line.contains(token) {
                    out["bank"] = bank.name
                    break outer
                }
            }
        }
        return out
    }

    // MARK: 주소

    static func parseAddress(lines: [String]) -> [String: String] {
        var out: [String: String] = [:]
        if let zip = firstMatch(#"\b\d{5}\b"#, in: lines.joined(separator: " ")) { out["zip"] = zip }
        // '로'/'길' + 번지가 들어간 줄을 도로명으로 본다
        if let road = lines.first(where: { line in
            line.contains("로 ") || line.contains("길 ") || line.contains("로") && line.rangeOfCharacter(from: .decimalDigits) != nil
        }) {
            out["road"] = road.trimmingCharacters(in: .whitespaces)
        }
        return out
    }

    // MARK: 와이파이 (공유기 스티커)

    static func parseWiFi(lines: [String]) -> [String: String] {
        var out: [String: String] = [:]
        for line in lines {
            let lower = line.lowercased()
            if out["ssid"] == nil, lower.contains("ssid") || lower.contains("network") {
                out["ssid"] = valueAfterLabel(line)
            }
            if out["password"] == nil,
               lower.contains("password") || lower.contains("pass") || lower.contains("key") || line.contains("비밀번호") {
                out["password"] = valueAfterLabel(line)
            }
        }
        return out.filter { !$0.value.isEmpty }
    }

    /// "SSID : MyWiFi" 처럼 라벨 뒤에 오는 값만 떼어낸다.
    static func valueAfterLabel(_ line: String) -> String {
        for sep in [":", "：", "="] {
            if let r = line.range(of: sep) {
                return String(line[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        }
        // 라벨만 있고 구분자가 없으면 마지막 낱말을 값으로 본다
        return line.split(separator: " ").last.map(String.init) ?? ""
    }

    // MARK: 신분·통관·차량

    static func parseCustoms(text: String) -> [String: String] {
        guard let m = firstMatch(#"[Pp]\s?\d{12}"#, in: text) else { return [:] }
        return ["customs": IdentityFormat.normalizeCustoms(m)]
    }

    static func parseRRN(text: String) -> [String: String] {
        guard let m = firstMatch(#"\d{6}\s?-\s?\d{7}"#, in: text) else { return [:] }
        let d = IdentityFormat.normalizeRRN(m)
        return IdentityFormat.isPlausibleRRN(d) ? ["rrn": d] : [:]
    }

    static func parsePassport(text: String) -> [String: String] {
        let upper = text.uppercased()
        for pattern in [#"\b[A-Z]\d{3}[A-Z]\d{4}\b"#, #"\b[A-Z]\d{8}\b"#] {
            if let m = firstMatch(pattern, in: upper) { return ["passport": m] }
        }
        return [:]
    }

    static func parseBiz(text: String) -> [String: String] {
        // 하이픈이 있는 형태를 먼저 찾고, 없으면 10자리 숫자 중 검증을 통과한 것만 쓴다.
        if let m = firstMatch(#"\d{3}\s?-\s?\d{2}\s?-\s?\d{5}"#, in: text) {
            let d = IdentityFormat.normalizeBiz(m)
            if IdentityFormat.isValidBiz(d) { return ["bizNumber": d] }
        }
        return [:]
    }

    static func parseLicense(text: String) -> [String: String] {
        guard let m = firstMatch(#"\d{2}\s?-\s?\d{2}\s?-\s?\d{6}\s?-\s?\d{2}"#, in: text) else { return [:] }
        return ["license": IdentityFormat.normalizeLicense(m)]
    }

    static func parseVehicle(text: String) -> [String: String] {
        guard let m = firstMatch(#"\d{2,3}[가-힣]\s?\d{4}"#, in: text) else { return [:] }
        return ["plate": m.replacingOccurrences(of: " ", with: "")]
    }

    // MARK: 도구

    static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let m = re.firstMatch(in: text, range: range),
              let r = Range(m.range, in: text) else { return nil }
        return String(text[r])
    }
}
