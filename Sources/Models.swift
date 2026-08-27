import Foundation
import SwiftData

// MARK: - 카테고리

enum VaultCategory: String, Codable, CaseIterable, Identifiable {
    case card, account, address, wifi, identity, doorlock, etc
    var id: String { rawValue }

    var title: String {
        switch self {
        case .card: return "카드"
        case .account: return "계좌"
        case .address: return "주소"
        case .wifi: return "와이파이"
        case .identity: return "신분"
        case .doorlock: return "도어록"
        case .etc: return "기타"
        }
    }

    var icon: String {
        switch self {
        case .card: return "creditcard.fill"
        case .account: return "building.columns.fill"
        case .address: return "house.fill"
        case .wifi: return "wifi"
        case .identity: return "person.text.rectangle.fill"
        case .doorlock: return "lock.shield.fill"
        case .etc: return "square.grid.2x2.fill"
        }
    }

    /// 카테고리 안에서 한 번 더 고르는 유형. 없으면 빈 배열.
    var subtypes: [VaultSubtype] {
        switch self {
        case .identity: return [.rrn, .passport, .license]
        case .etc: return [.customs, .vehicle, .business, .insurance, .memo]
        default: return []
        }
    }
}

enum VaultSubtype: String, Codable, CaseIterable, Identifiable {
    case rrn, passport, license, customs, vehicle, business, insurance, memo
    var id: String { rawValue }

    var title: String {
        switch self {
        case .rrn: return "주민등록번호"
        case .passport: return "여권"
        case .license: return "운전면허"
        case .customs: return "통관부호"
        case .vehicle: return "차량"
        case .business: return "사업자"
        case .insurance: return "보험"
        case .memo: return "자유 메모"
        }
    }
}

// MARK: - 입력 필드 스키마
// 카테고리·유형을 고르면 이 스키마대로 입력칸이 바뀐다.
// 화면 코드에 필드를 하드코딩하지 않으므로 카테고리를 늘리기 쉽다.

enum FieldKind: String, Codable {
    case text, multiline, number
    case account          // 계좌번호 — 숫자 그대로
    case cardNumber       // 카드번호 — 브랜드별 칸 분할
    case expiry           // MM/YY
    case cvc
    case rrn, passport, customs, vehicle
    case password         // 카드·계좌·도어록 비밀번호
    case bizNumber        // 사업자등록번호
    case license          // 운전면허번호
    case wifiPassword
    case date             // 날짜 — 숫자로 넣고 2025.03.31 로 보여줌
    case province         // 시·도 — 목록에서 고름
    case district         // 시·군·구 — 고른 시·도에 따라 목록이 바뀜
    case cardIssuer       // 카드사 — 글자 칠 때마다 후보
    case bank             // 은행 — 글자 칠 때마다 후보
}

struct FieldSpec: Identifiable {
    let key: String
    let label: String
    let kind: FieldKind
    var sensitive: Bool = false     // 기본 마스킹 대상
    var placeholder: String = ""
    var optional: Bool = false      // 비워둬도 되는 칸
    var id: String { key }
}

enum VaultSchema {
    static func fields(for category: VaultCategory, subtype: VaultSubtype?) -> [FieldSpec] {
        switch category {
        case .card:
            return [
                FieldSpec(key: "issuer", label: "카드사", kind: .cardIssuer,
                          placeholder: "이름을 입력하면 아래에 나옵니다"),
                FieldSpec(key: "number", label: "카드번호", kind: .cardNumber, sensitive: true,
                          placeholder: "숫자만 입력하세요"),
                FieldSpec(key: "expiry", label: "유효기간", kind: .expiry, placeholder: "MM/YY"),
                FieldSpec(key: "cvc", label: "CVC", kind: .cvc, sensitive: true, placeholder: "뒷면 3자리"),
                FieldSpec(key: "pin", label: "카드 비밀번호", kind: .password, sensitive: true,
                          placeholder: "선택", optional: true),
            ]
        case .account:
            return [
                FieldSpec(key: "bank", label: "은행", kind: .bank,
                          placeholder: "이름을 입력하면 아래에 나옵니다"),
                FieldSpec(key: "number", label: "계좌번호", kind: .account, sensitive: true,
                          placeholder: "숫자만 쭉 입력하세요"),
                FieldSpec(key: "holder", label: "예금주", kind: .text),
                FieldSpec(key: "pin", label: "계좌 비밀번호", kind: .password, sensitive: true,
                          placeholder: "선택", optional: true),
            ]
        case .address:
            return [
                FieldSpec(key: "province", label: "시 · 도", kind: .province),
                FieldSpec(key: "district", label: "시 · 군 · 구", kind: .district),
                FieldSpec(key: "road", label: "도로명 이하", kind: .text,
                          placeholder: "예: 율곡로 83"),
                FieldSpec(key: "detail", label: "상세 주소", kind: .text,
                          placeholder: "선택 (동·호수 등)", optional: true),
                FieldSpec(key: "zip", label: "우편번호", kind: .number,
                          placeholder: "선택", optional: true),
            ]
        case .wifi:
            return [
                FieldSpec(key: "ssid", label: "네트워크 이름(SSID)", kind: .text),
                FieldSpec(key: "password", label: "비밀번호", kind: .wifiPassword, sensitive: true),
                FieldSpec(key: "security", label: "보안 방식", kind: .text, placeholder: "WPA / WEP / 없음"),
            ]
        case .identity:
            switch subtype {
            case .license:
                return [
                    FieldSpec(key: "license", label: "운전면허번호", kind: .license, sensitive: true,
                              placeholder: "숫자 12자리"),
                    FieldSpec(key: "name", label: "이름", kind: .text),
                    FieldSpec(key: "issued", label: "발행일", kind: .date,
                              placeholder: "예: 20250331", optional: true),
                    FieldSpec(key: "expiry", label: "갱신 만료일", kind: .date,
                              placeholder: "선택 (예: 20300101)", optional: true),
                ]
            case .passport:
                return [
                    FieldSpec(key: "passport", label: "여권번호", kind: .passport, sensitive: true,
                              placeholder: "M12345678 또는 M123A4567"),
                    FieldSpec(key: "name", label: "영문 이름", kind: .text),
                    FieldSpec(key: "issued", label: "발행일", kind: .date,
                              placeholder: "예: 20250331", optional: true),
                    FieldSpec(key: "expiry", label: "만료일", kind: .date, placeholder: "예: 20300101"),
                ]
            default:
                return [
                    FieldSpec(key: "rrn", label: "주민등록번호", kind: .rrn, sensitive: true,
                              placeholder: "숫자 13자리"),
                    FieldSpec(key: "name", label: "명의자", kind: .text),
                    FieldSpec(key: "issued", label: "발행일", kind: .date,
                              placeholder: "예: 20250331", optional: true),
                ]
            }
        case .doorlock:
            return [
                FieldSpec(key: "place", label: "어디", kind: .text, placeholder: "예: 우리집 현관"),
                FieldSpec(key: "code", label: "비밀번호", kind: .password, sensitive: true),
                FieldSpec(key: "note", label: "메모", kind: .text,
                          placeholder: "선택 (예: 별표 두 번 누르고 입력)", optional: true),
            ]
        case .etc where subtype == .business:
            return [
                FieldSpec(key: "name", label: "상호", kind: .text),
                FieldSpec(key: "bizNumber", label: "사업자등록번호", kind: .bizNumber, sensitive: true,
                          placeholder: "숫자 10자리"),
                FieldSpec(key: "owner", label: "대표자", kind: .text),
                FieldSpec(key: "category", label: "업태 / 종목", kind: .text,
                          placeholder: "예: 서비스업 / 광고대행"),
                FieldSpec(key: "province", label: "시 · 도", kind: .province),
                FieldSpec(key: "district", label: "시 · 군 · 구", kind: .district),
                FieldSpec(key: "address", label: "이하 주소", kind: .text,
                          placeholder: "예: 율곡로 83, 3층"),
                FieldSpec(key: "email", label: "계산서 이메일", kind: .text,
                          placeholder: "선택", optional: true),
            ]
        case .etc:
            switch subtype {
            case .business:
                return []   // 위의 where 절에서 처리
            case .customs:
                return [
                    FieldSpec(key: "customs", label: "개인통관고유부호", kind: .customs, sensitive: true,
                              placeholder: "P로 시작하는 13자"),
                    FieldSpec(key: "name", label: "명의자", kind: .text),
                ]
            case .vehicle:
                return [
                    FieldSpec(key: "plate", label: "차량번호", kind: .vehicle, placeholder: "12가3456"),
                    FieldSpec(key: "model", label: "차종", kind: .text),
                ]
            case .insurance:
                return [
                    FieldSpec(key: "company", label: "보험사", kind: .text),
                    FieldSpec(key: "policy", label: "증권번호", kind: .text, sensitive: true),
                    FieldSpec(key: "target", label: "대상", kind: .text,
                              placeholder: "예: 쏘나타 12가3456"),
                    FieldSpec(key: "phone", label: "사고접수 번호", kind: .text,
                              placeholder: "선택", optional: true),
                ]
            default:
                return [FieldSpec(key: "body", label: "내용", kind: .multiline, sensitive: true)]
            }
        }
    }
}

// MARK: - 저장 모델
// 값은 통째로 암호화해 `encrypted`에 넣는다. 평문으로 남는 건 검색용 별칭뿐이다.

@Model
final class VaultItem {
    var id: UUID = UUID()
    var categoryRaw: String = VaultCategory.card.rawValue
    var subtypeRaw: String?
    /// 검색·목록 표시용 별칭. 민감정보를 넣지 않도록 안내한다.
    var title: String = ""
    /// 계좌면 은행 코드, 카드면 브랜드 — 표시 형식을 고르는 데만 쓴다.
    var formatHint: String?
    var isFavorite: Bool = false
    /// 직접 고른 아이콘(SF Symbol 이름). 비우면 카테고리 기본 아이콘을 쓴다.
    /// 아이콘 이름은 민감한 값이 아니라 암호화하지 않는다.
    var iconName: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    /// 필드 전체를 JSON으로 만들어 AES-GCM으로 암호화한 결과
    var encrypted: Data = Data()

    init(category: VaultCategory, subtype: VaultSubtype?, title: String,
         formatHint: String?, encrypted: Data) {
        self.categoryRaw = category.rawValue
        self.subtypeRaw = subtype?.rawValue
        self.title = title
        self.formatHint = formatHint
        self.encrypted = encrypted
    }

    var category: VaultCategory { VaultCategory(rawValue: categoryRaw) ?? .etc }

    /// 목록·상세에 쓸 아이콘. 고른 게 없으면 카테고리 기본값.
    var icon: String { iconName ?? category.icon }
    var subtype: VaultSubtype? { subtypeRaw.flatMap(VaultSubtype.init(rawValue:)) }

    func values() -> [String: String] {
        guard !encrypted.isEmpty,
              let json = try? VaultCrypto.open(encrypted),
              let data = json.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return dict
    }

    /// 목록에 보이는 이름.
    /// 별칭을 비워두면 카테고리에 맞는 대표 정보로 대신 보여준다.
    /// (계좌=은행명, 카드=카드사, 통관부호=유형 이름)
    var displayTitle: String {
        if !title.isEmpty { return title }
        let v = values()
        switch category {
        case .card:    return v["issuer"] ?? "카드"
        case .account: return v["bank"] ?? "계좌"
        case .wifi:    return v["ssid"] ?? "와이파이"
        case .address:
            let joined = ["province", "district", "road"]
                .compactMap { v[$0] }.filter { !$0.isEmpty }.joined(separator: " ")
            return joined.isEmpty ? "주소" : joined

        case .doorlock: return v["place"] ?? "도어록"
        case .identity, .etc:
            if subtype == .business, let n = v["name"], !n.isEmpty { return n }
            if subtype == .insurance, let c = v["company"], !c.isEmpty { return c }
            return subtype?.title ?? category.title
        }
    }

    /// 목록 뱃지에 쓸 기관(카드사·은행). 없으면 nil.
    var institution: Institution? {
        let v = values()
        switch category {
        case .card:    return (v["issuer"]).flatMap(Institutions.find)
        case .account: return (v["bank"]).flatMap(Institutions.find)
        default:       return nil
        }
    }

    /// 검색 대상 텍스트 — 별칭·카테고리·유형에 더해 저장한 값까지 훑는다.
    func searchHaystack() -> String {
        var parts = [title, category.title, subtype?.title ?? ""]
        parts.append(contentsOf: values().values)
        return parts.joined(separator: " ")
    }

    func setValues(_ dict: [String: String]) throws {
        let data = try JSONEncoder().encode(dict)
        encrypted = try VaultCrypto.seal(String(decoding: data, as: UTF8.self))
        updatedAt = Date()
    }
}


/// 아이템에 붙일 수 있는 아이콘 모음.
enum VaultIcons {
    static let all: [String] = [
        "creditcard.fill", "building.columns.fill", "wonsign.circle.fill", "banknote.fill",
        "house.fill", "building.2.fill", "storefront.fill", "briefcase.fill",
        "wifi", "qrcode", "key.fill", "lock.fill",
        "person.text.rectangle.fill", "person.crop.circle.fill", "figure.2.and.child.holdinghands",
        "airplane", "car.fill", "bus.fill", "bicycle",
        "cart.fill", "gift.fill", "shippingbox.fill",
        "heart.fill", "cross.case.fill", "pawprint.fill",
        "graduationcap.fill", "book.fill", "star.fill",
        "phone.fill", "envelope.fill", "doc.text.fill", "tag.fill",
    ]
}


/// 카테고리 구성이 바뀌기 전에 저장된 항목을 새 구조로 옮긴다.
/// (사업자: 독립 카테고리 → 기타의 유형 / 도어록: 기타의 유형 → 독립 카테고리)
enum VaultMigration {
    static func run(_ context: ModelContext) {
        guard let items = try? context.fetch(FetchDescriptor<VaultItem>()) else { return }
        var changed = false
        for item in items {
            if item.categoryRaw == "business" {
                item.categoryRaw = VaultCategory.etc.rawValue
                item.subtypeRaw = VaultSubtype.business.rawValue
                changed = true
            } else if item.categoryRaw == VaultCategory.etc.rawValue,
                      item.subtypeRaw == "doorlock" {
                item.categoryRaw = VaultCategory.doorlock.rawValue
                item.subtypeRaw = nil
                changed = true
            }
        }
        if changed { try? context.save() }
    }
}
