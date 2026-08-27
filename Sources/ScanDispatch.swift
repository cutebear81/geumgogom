import Foundation

/// 카테고리에 맞는 파서를 고른다.
/// ScanParser 자체는 모델을 모르는 순수 문자열 로직이라 따로 검증할 수 있다.
extension ScanParser {
    static func parse(lines: [String], category: VaultCategory, subtype: VaultSubtype?) -> [String: String] {
        let joined = lines.joined(separator: "\n")
        switch category {
        case .card:     return parseCard(lines: lines, text: joined)
        case .account:  return parseAccount(lines: lines)
        case .address:  return parseAddress(lines: lines)
        case .wifi:     return parseWiFi(lines: lines)
        case .identity:
            switch subtype {
            case .passport: return parsePassport(text: joined)
            case .license:  return parseLicense(text: joined)
            default:        return parseRRN(text: joined)
            }
        case .doorlock: return [:]   // 도어록은 촬영으로 읽을 게 없다
        case .etc:
            switch subtype {
            case .business: return parseBiz(text: joined)
            case .vehicle: return parseVehicle(text: joined)
            case .memo:    return ["body": joined]
            default:       return parseCustoms(text: joined)
            }
        }
    }
}
