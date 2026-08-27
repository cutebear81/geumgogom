import Foundation

/// 카드 브랜드. 칸 개수가 브랜드마다 다르므로 4-4-4-4로 고정하면 안 된다.
/// (아멕스 15자리 4-6-5, 다이너스 14자리 4-6-4)
enum CardBrand: String, Codable, CaseIterable {
    case visa, mastercard, amex, jcb, unionPay, diners, unknown

    var displayName: String {
        switch self {
        case .visa: return "Visa"
        case .mastercard: return "Mastercard"
        case .amex: return "American Express"
        case .jcb: return "JCB"
        case .unionPay: return "UnionPay"
        case .diners: return "Diners Club"
        case .unknown: return "카드"
        }
    }

    /// 하이픈 구간 자릿수
    var groups: [Int] {
        switch self {
        case .amex: return [4, 6, 5]
        case .diners: return [4, 6, 4]
        default: return [4, 4, 4, 4]
        }
    }

    var digitCount: Int { groups.reduce(0, +) }
}

enum CardFormat {
    static func normalize(_ input: String) -> String { input.filter(\.isNumber) }

    /// IIN(앞자리)으로 브랜드 판별. 국제 표준이라 은행 계좌와 달리 안정적이다.
    static func brand(of input: String) -> CardBrand {
        let d = normalize(input)
        guard let first = d.first else { return .unknown }
        func num(_ n: Int) -> Int? { d.count >= n ? Int(d.prefix(n)) : nil }

        if first == "4" { return .visa }
        if let two = num(2) {
            if two == 34 || two == 37 { return .amex }
            if (51...55).contains(two) { return .mastercard }
            if two == 35 { return .jcb }
            if two == 62 { return .unionPay }
            if two == 36 || two == 38 { return .diners }
            if two == 30, let three = num(3), (300...305).contains(three) { return .diners }
        }
        if let four = num(4), (2221...2720).contains(four) { return .mastercard }
        return .unknown
    }

    static func display(_ input: String) -> String {
        let d = normalize(input)
        let groups = brand(of: d).groups
        var out: [String] = []
        var idx = d.startIndex
        for g in groups {
            guard idx < d.endIndex else { break }
            let end = d.index(idx, offsetBy: g, limitedBy: d.endIndex) ?? d.endIndex
            out.append(String(d[idx..<end]))
            idx = end
        }
        if idx < d.endIndex { out.append(String(d[idx...])) }   // 규격보다 길면 잘라내지 않고 뒤에 붙인다
        return out.joined(separator: "-")
    }

    static func segments(_ input: String) -> [String] {
        display(input).components(separatedBy: "-")
    }

    /// Luhn 검사 — 오타를 입력 즉시 잡는다. 오프라인 계산이라 비용이 없다.
    static func isLuhnValid(_ input: String) -> Bool {
        let d = normalize(input)
        guard d.count >= 12 else { return false }
        var sum = 0
        for (i, ch) in d.reversed().enumerated() {
            guard var v = ch.wholeNumberValue else { return false }
            if i % 2 == 1 { v *= 2; if v > 9 { v -= 9 } }
            sum += v
        }
        return sum % 10 == 0
    }

    /// 마스킹 표시. 뒤 4자리만 남긴다.
    static func masked(_ input: String) -> String {
        let d = normalize(input)
        guard d.count > 4 else { return String(repeating: "•", count: d.count) }
        let tail = d.suffix(4)
        let groups = brand(of: d).groups
        let hidden = groups.dropLast().map { String(repeating: "•", count: $0) }
        return (hidden + [String(tail)]).joined(separator: "-")
    }
}
