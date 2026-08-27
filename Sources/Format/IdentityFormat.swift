import Foundation

/// 신분·통관 관련 번호 형식.
enum IdentityFormat {

    // MARK: 개인통관고유부호 — P + 숫자 12자리 (총 13자)
    static func normalizeCustoms(_ input: String) -> String {
        let s = input.uppercased().filter { $0.isNumber || $0 == "P" }
        let digits = s.filter(\.isNumber).prefix(12)
        return digits.isEmpty ? "" : "P" + digits
    }

    static func isValidCustoms(_ input: String) -> Bool {
        let s = normalizeCustoms(input)
        return s.count == 13 && s.hasPrefix("P")
    }

    // MARK: 주민등록번호 — 13자리, 6-7 표시
    /// ⚠️ 체크섬(마지막 자리) 검증은 하지 않는다.
    /// 2020년 10월부터 뒤 7자리 중 성별을 제외한 2~7번째가 임의번호로 바뀌어
    /// 기존 검증식이 신규 발급분에 성립하지 않는다. 검증을 넣으면 멀쩡한 번호를 튕겨낸다.
    static func normalizeRRN(_ input: String) -> String {
        String(input.filter(\.isNumber).prefix(13))
    }

    static func displayRRN(_ input: String) -> String {
        let d = normalizeRRN(input)
        guard d.count > 6 else { return d }
        let i = d.index(d.startIndex, offsetBy: 6)
        return d[..<i] + "-" + d[i...]
    }

    /// 자릿수 + 생년월일 형식 + 성별코드까지만 확인한다.
    static func isPlausibleRRN(_ input: String) -> Bool {
        let d = normalizeRRN(input)
        guard d.count == 13 else { return false }
        let mm = Int(d[d.index(d.startIndex, offsetBy: 2)..<d.index(d.startIndex, offsetBy: 4)]) ?? 0
        let dd = Int(d[d.index(d.startIndex, offsetBy: 4)..<d.index(d.startIndex, offsetBy: 6)]) ?? 0
        let gender = d[d.index(d.startIndex, offsetBy: 6)].wholeNumberValue ?? 0
        return (1...12).contains(mm) && (1...31).contains(dd) && (1...8).contains(gender)
    }

    static func maskedRRN(_ input: String) -> String {
        let d = normalizeRRN(input)
        guard d.count == 13 else { return String(repeating: "•", count: d.count) }
        return d.prefix(6) + "-" + d.prefix(7).suffix(1) + "••••••"
    }

    // MARK: 여권번호
    /// 구형 `M12345678`(영문1+숫자8)과 차세대 `M123A4567`(영문1+숫자3+영문1+숫자4)이 함께 쓰인다.
    /// 두 형식 모두 9자이므로 길이와 문자 구성만 확인한다.
    static func normalizePassport(_ input: String) -> String {
        String(input.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(9))
    }

    static func isValidPassport(_ input: String) -> Bool {
        let s = normalizePassport(input)
        guard s.count == 9, let first = s.first, first.isLetter else { return false }
        let old = s.dropFirst().allSatisfy(\.isNumber)
        let new = s.count == 9 && s.dropFirst().enumerated().allSatisfy { i, c in
            i == 3 ? c.isLetter : c.isNumber
        }
        return old || new
    }
}

extension IdentityFormat {

    // MARK: 사업자등록번호 — 10자리, 3-2-5 표시
    static func normalizeBiz(_ input: String) -> String {
        String(input.filter(\.isNumber).prefix(10))
    }

    static func displayBiz(_ input: String) -> String {
        let d = normalizeBiz(input)
        guard d.count == 10 else { return d }
        let i3 = d.index(d.startIndex, offsetBy: 3)
        let i5 = d.index(d.startIndex, offsetBy: 5)
        return "\(d[..<i3])-\(d[i3..<i5])-\(d[i5...])"
    }

    /// 국세청 검증식으로 오타를 잡는다.
    /// 앞 9자리에 가중치 1,3,7,1,3,7,1,3,5를 곱해 더하고, 9번째 자리×5를 10으로 나눈 몫을 더한 뒤
    /// 10에서 나머지를 뺀 값이 마지막 자리와 같아야 한다.
    static func isValidBiz(_ input: String) -> Bool {
        let d = normalizeBiz(input).compactMap(\.wholeNumberValue)
        guard d.count == 10 else { return false }
        let weights = [1, 3, 7, 1, 3, 7, 1, 3, 5]
        var sum = zip(d.prefix(9), weights).reduce(0) { $0 + $1.0 * $1.1 }
        sum += (d[8] * 5) / 10
        return (10 - sum % 10) % 10 == d[9]
    }

    // MARK: 운전면허번호 — 12자리, AA-BB-CCCCCC-DE
    static func normalizeLicense(_ input: String) -> String {
        String(input.filter(\.isNumber).prefix(12))
    }

    static func displayLicense(_ input: String) -> String {
        let d = normalizeLicense(input)
        guard d.count == 12 else { return d }
        func part(_ a: Int, _ b: Int) -> String {
            String(d[d.index(d.startIndex, offsetBy: a)..<d.index(d.startIndex, offsetBy: b)])
        }
        return "\(part(0,2))-\(part(2,4))-\(part(4,10))-\(part(10,12))"
    }

    /// 자릿수만 본다. 체크섬 규칙은 공식 공개 자료가 없어 검증하지 않는다.
    static func isValidLicense(_ input: String) -> Bool {
        normalizeLicense(input).count == 12
    }
}

/// 날짜 입력 — 숫자만 저장하고 볼 때 점을 찍어 보여준다.
enum DateFormat {
    static func normalize(_ input: String) -> String {
        String(input.filter(\.isNumber).prefix(8))
    }

    /// 8자리면 2025.03.31, 6자리면 2025.03. 그 외에는 숫자를 그대로 둔다.
    static func display(_ input: String) -> String {
        let d = normalize(input)
        func part(_ a: Int, _ b: Int) -> String {
            String(d[d.index(d.startIndex, offsetBy: a)..<d.index(d.startIndex, offsetBy: b)])
        }
        switch d.count {
        case 8: return "\(part(0,4)).\(part(4,6)).\(part(6,8))"
        case 6: return "\(part(0,4)).\(part(4,6))"
        default: return d
        }
    }

    /// 말이 되는 날짜인지 — 월 1~12, 일 1~31까지만 본다.
    static func isPlausible(_ input: String) -> Bool {
        let d = normalize(input)
        guard d.count == 8,
              let m = Int(String(d.dropFirst(4).prefix(2))),
              let day = Int(String(d.suffix(2))) else { return false }
        return (1...12).contains(m) && (1...31).contains(day)
    }
}
