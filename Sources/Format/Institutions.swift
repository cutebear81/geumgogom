import Foundation

/// 카드사·은행 이름 인덱스.
/// 글자를 칠 때마다 후보를 좁혀 고르게 하기 위한 목록이다. 계좌번호로 은행을 추측하지 않는다.
struct Institution: Identifiable, Hashable {
    let name: String
    let aliases: [String]
    /// 목록에서 쓰는 짧은 표기(한두 글자)
    let short: String
    /// 구분용 색. **로고를 쓰지 않는다** — 제3자 상표는 권한 없이 앱에 넣을 수 없어서,
    /// 각 사의 색 계열만 참고해 눈으로 구분되게 한 것이다.
    let tint: String
    var id: String { name }
}

enum Institutions {
    /// 국내 카드사
    static let cardIssuers: [Institution] = [
        .init(name: "신한카드", aliases: ["shinhan"], short: "신", tint: "0046FF"),
        .init(name: "삼성카드", aliases: ["samsung"], short: "삼", tint: "1428A0"),
        .init(name: "KB국민카드", aliases: ["국민", "kb", "케이비"], short: "국", tint: "FFBC00"),
        .init(name: "현대카드", aliases: ["hyundai"], short: "현", tint: "1A1A1A"),
        .init(name: "롯데카드", aliases: ["lotte"], short: "롯", tint: "E60012"),
        .init(name: "우리카드", aliases: ["woori"], short: "우", tint: "0067AC"),
        .init(name: "하나카드", aliases: ["hana"], short: "하", tint: "008485"),
        .init(name: "BC카드", aliases: ["비씨", "bc"], short: "BC", tint: "E4002B"),
        .init(name: "NH농협카드", aliases: ["농협", "nh"], short: "농", tint: "19A24A"),
        .init(name: "씨티카드", aliases: ["citi"], short: "씨", tint: "003B70"),
        .init(name: "카카오뱅크", aliases: ["카뱅", "kakao"], short: "카", tint: "FFCD00"),
        .init(name: "토스뱅크", aliases: ["토스", "toss"], short: "토", tint: "0064FF"),
        .init(name: "케이뱅크", aliases: ["케뱅", "kbank"], short: "케", tint: "3E5BFF"),
        .init(name: "새마을금고", aliases: ["새마을", "mg"], short: "MG", tint: "00539F"),
        .init(name: "신협", aliases: [], short: "신협", tint: "0067B1"),
        .init(name: "우체국", aliases: ["포스트"], short: "우체", tint: "E4002B"),
        .init(name: "수협", aliases: ["sh"], short: "수", tint: "0068B7"),
        .init(name: "광주은행", aliases: ["광주"], short: "광", tint: "0072CE"),
        .init(name: "전북은행", aliases: ["전북"], short: "전", tint: "0071B6"),
        .init(name: "제주은행", aliases: ["제주"], short: "제", tint: "00A0DF"),
    ]

    /// 국내 은행
    static let banks: [Institution] = [
        .init(name: "KB국민은행", aliases: ["국민", "kb", "케이비"], short: "국", tint: "FFBC00"),
        .init(name: "신한은행", aliases: ["shinhan"], short: "신", tint: "0046FF"),
        .init(name: "우리은행", aliases: ["woori"], short: "우", tint: "0067AC"),
        .init(name: "하나은행", aliases: ["hana"], short: "하", tint: "008485"),
        .init(name: "NH농협은행", aliases: ["농협", "nh"], short: "농", tint: "19A24A"),
        .init(name: "IBK기업은행", aliases: ["기업", "ibk"], short: "기", tint: "0067B3"),
        .init(name: "SC제일은행", aliases: ["제일", "sc"], short: "SC", tint: "0F7B6C"),
        .init(name: "한국씨티은행", aliases: ["씨티", "citi"], short: "씨", tint: "003B70"),
        .init(name: "카카오뱅크", aliases: ["카뱅", "kakao"], short: "카", tint: "FFCD00"),
        .init(name: "토스뱅크", aliases: ["토스", "toss"], short: "토", tint: "0064FF"),
        .init(name: "케이뱅크", aliases: ["케뱅", "kbank"], short: "케", tint: "3E5BFF"),
        .init(name: "부산은행", aliases: ["부산", "bnk"], short: "부", tint: "E4002B"),
        .init(name: "iM뱅크", aliases: ["대구", "대구은행", "im"], short: "iM", tint: "0071CE"),
        .init(name: "경남은행", aliases: ["경남"], short: "경", tint: "C8102E"),
        .init(name: "광주은행", aliases: ["광주"], short: "광", tint: "0072CE"),
        .init(name: "전북은행", aliases: ["전북"], short: "전", tint: "0071B6"),
        .init(name: "제주은행", aliases: ["제주"], short: "제", tint: "00A0DF"),
        .init(name: "Sh수협은행", aliases: ["수협", "sh"], short: "수", tint: "0068B7"),
        .init(name: "새마을금고", aliases: ["새마을", "mg"], short: "MG", tint: "00539F"),
        .init(name: "신협", aliases: [], short: "신협", tint: "0067B1"),
        .init(name: "우체국예금", aliases: ["우체국", "포스트"], short: "우체", tint: "E4002B"),
        .init(name: "KDB산업은행", aliases: ["산업", "kdb"], short: "산", tint: "0057A8"),
    ]

    /// 입력한 글자로 후보를 좁힌다. 빈 입력이면 전체 목록(최근 쓴 것 먼저).
    static func search(_ query: String, in list: [Institution],
                       recent: [String] = [], limit: Int = 8) -> [Institution] {
        var hits: [Institution] = []
        for item in list where KoreanSearch.matches(item.name, aliases: item.aliases, query: query) {
            hits.append(item)
        }
        // 최근 고른 것을 앞으로
        var ordered: [Institution] = []
        for name in recent {
            if let found = hits.first(where: { $0.name == name }) { ordered.append(found) }
        }
        for item in hits where !ordered.contains(item) { ordered.append(item) }
        return Array(ordered.prefix(limit))
    }
}


extension Institutions {
    /// 이름으로 기관을 찾는다. 카드사·은행을 모두 뒤진다.
    static func find(_ name: String) -> Institution? {
        banks.first { $0.name == name } ?? cardIssuers.first { $0.name == name }
    }
}
