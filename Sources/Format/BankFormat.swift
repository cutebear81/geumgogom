import Foundation

/// 계좌번호는 숫자만 저장하고 숫자 그대로 보여준다.
/// 은행마다 하이픈 위치가 달라 자동으로 넣으면 틀릴 수 있고, 하이픈은 이체에 영향이 없다.
/// 은행은 추측하지 않고 사용자가 이름으로 찾아 고른다.
enum BankFormat {
    static func normalize(_ input: String) -> String {
        input.filter(\.isNumber)
    }
}
