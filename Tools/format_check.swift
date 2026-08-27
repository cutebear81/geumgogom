// 금고곰 포맷터 자체 점검
func expect(_ cond: Bool, _ label: String) {
    print((cond ? "  ok  " : "  FAIL") + " " + label)
    if !cond { fatalError("실패: " + label) }
}

print("[계좌]")
expect(BankFormat.normalize("110-123-456789") == "110123456789", "정규화: 숫자만 남음 (하이픈은 저장도 표시도 안 함)")

print("[카드]")
expect(CardFormat.brand(of: "4111111111111111") == .visa, "4 → Visa")
expect(CardFormat.brand(of: "5500000000000004") == .mastercard, "55 → Mastercard")
expect(CardFormat.brand(of: "2221000000000009") == .mastercard, "2221 → Mastercard")
expect(CardFormat.brand(of: "378282246310005") == .amex, "37 → Amex")
expect(CardFormat.brand(of: "3530111333300000") == .jcb, "35 → JCB")
expect(CardFormat.display("378282246310005") == "3782-822463-10005", "아멕스 4-6-5 (4칸 고정이면 깨지는 자리)")
expect(CardFormat.display("4111111111111111") == "4111-1111-1111-1111", "비자 4-4-4-4")
expect(CardFormat.isLuhnValid("4111111111111111"), "Luhn 통과")
expect(!CardFormat.isLuhnValid("4111111111111112"), "Luhn 오타 검출")
expect(CardFormat.masked("4111111111111111") == "••••-••••-••••-1111", "마스킹")

print("[신분·통관]")
expect(IdentityFormat.normalizeCustoms("p123456789012") == "P123456789012", "통관부호 P 대문자 + 12자리")
expect(IdentityFormat.isValidCustoms("P123456789012"), "통관부호 13자 검증")
expect(!IdentityFormat.isValidCustoms("P12345"), "통관부호 자릿수 미달 거부")
expect(IdentityFormat.displayRRN("9001011234567") == "900101-1234567", "주민번호 6-7 표시")
expect(IdentityFormat.isPlausibleRRN("9001011234567"), "주민번호 형식 통과")
expect(!IdentityFormat.isPlausibleRRN("9013011234567"), "13월 거부")
expect(IdentityFormat.isPlausibleRRN("0301013456789"), "2020년 이후 임의번호도 통과 — 체크섬 검증 안 함")
expect(IdentityFormat.maskedRRN("9001011234567") == "900101-1••••••", "주민번호 마스킹")
expect(IdentityFormat.isValidPassport("M12345678"), "구형 여권 M+숫자8")
expect(IdentityFormat.isValidPassport("M123A4567"), "차세대 여권 M123A4567")
expect(!IdentityFormat.isValidPassport("M1234567"), "8자리 거부")

print("\n전부 통과")

print("[촬영 인식]")
expect(ScanParser.parseCard(lines: ["KB국민카드", "4111 1111 1111 1111", "VALID THRU 09/28"],
                            text: "KB국민카드\n4111 1111 1111 1111\nVALID THRU 09/28")["number"] == "4111111111111111",
       "카드번호 인식 (Luhn 통과분만)")
expect(ScanParser.parseCard(lines: ["1234 5678 9012 3456"], text: "1234 5678 9012 3456")["number"] == nil,
       "Luhn 실패 숫자는 카드번호로 안 잡음")
expect(ScanParser.parseCard(lines: [], text: "VALID THRU 09/28")["expiry"] == "09/28", "유효기간 인식")
expect(ScanParser.parseCard(lines: [], text: "13/28")["expiry"] == nil, "13월은 유효기간 아님")
expect(ScanParser.parseAccount(lines: ["신한", "110-123-456789"])["number"] == "110123456789", "계좌번호 인식")
expect(ScanParser.parseAccount(lines: ["신한은행", "110-123-456789"])["bank"] == "신한은행", "통장에 찍힌 은행 이름 인식")
expect(ScanParser.parseCustoms(text: "개인통관고유부호 P123456789012")["customs"] == "P123456789012", "통관부호 인식")
expect(ScanParser.parseRRN(text: "900101-1234567")["rrn"] == "9001011234567", "주민번호 인식")
expect(ScanParser.parseRRN(text: "901301-1234567").isEmpty, "말이 안 되는 주민번호는 버림")
expect(ScanParser.parsePassport(text: "Passport No. M123A4567")["passport"] == "M123A4567", "차세대 여권 인식")
expect(ScanParser.parsePassport(text: "M12345678")["passport"] == "M12345678", "구형 여권 인식")
expect(ScanParser.parseVehicle(text: "차량번호 12가3456")["plate"] == "12가3456", "차량번호 인식")
expect(ScanParser.parseWiFi(lines: ["SSID : TONYNE_5G", "Password : abcd1234"])["password"] == "abcd1234", "와이파이 비번 인식")
expect(ScanParser.valueAfterLabel("SSID : TONYNE_5G") == "TONYNE_5G", "라벨 뒤 값만 떼어냄")

print("\n촬영 인식까지 전부 통과")

print("[기관 인덱스]")
expect(KoreanSearch.initials(of: "국민은행") == "ㄱㅁㅇㅎ", "초성 추출")
expect(KoreanSearch.isInitialsOnly("ㄱㅁ"), "초성만 입력 판별")
expect(!KoreanSearch.isInitialsOnly("국"), "완성 글자는 초성검색 아님")
expect(KoreanSearch.matches("KB국민은행", aliases: ["국민","kb"], query: "국"), "한 글자로 걸림")
expect(KoreanSearch.matches("KB국민은행", aliases: ["국민","kb"], query: "국민"), "두 글자로 걸림")
expect(KoreanSearch.matches("KB국민은행", aliases: ["국민","kb"], query: "kb"), "영문 별칭으로 걸림")
expect(KoreanSearch.matches("신한카드", aliases: [], query: "ㅅㅎ"), "초성 검색")
expect(!KoreanSearch.matches("신한카드", aliases: [], query: "삼성"), "관계없는 검색어는 안 걸림")
expect(Institutions.search("신", in: Institutions.banks).contains { $0.name == "신한은행" }, "'신' → 신한은행")
expect(Institutions.search("ㅋㅋ", in: Institutions.banks).contains { $0.name == "카카오뱅크" }, "'ㅋㅋ' → 카카오뱅크")
expect(Institutions.search("토스", in: Institutions.cardIssuers).first?.name == "토스뱅크", "카드사에서도 검색")
expect(Institutions.search("대구", in: Institutions.banks).first?.name == "iM뱅크", "옛 이름(대구)으로 iM뱅크")
expect(Institutions.search("", in: Institutions.banks, recent: ["토스뱅크"]).first?.name == "토스뱅크", "최근 고른 것 우선")

print("\n기관 인덱스까지 전부 통과")

print("[사업자·면허]")
expect(IdentityFormat.displayBiz("1234567890") == "123-45-67890", "사업자번호 3-2-5 표시")
expect(IdentityFormat.isValidBiz("1208147521"), "국세청 검증식 통과 (실제 유효 번호 형태)")
expect(!IdentityFormat.isValidBiz("1208147522"), "마지막 자리 틀리면 거부")
expect(!IdentityFormat.isValidBiz("12345"), "자릿수 미달 거부")
expect(IdentityFormat.displayLicense("112233333344") == "11-22-333333-44", "면허번호 2-2-6-2 표시")
expect(IdentityFormat.isValidLicense("112233333344"), "면허번호 12자리")
expect(!IdentityFormat.isValidLicense("1122333333"), "10자리는 거부")

print("\n사업자·면허까지 전부 통과")

print("[촬영 인식 · 추가분]")
expect(ScanParser.parseBiz(text: "사업자등록번호 120-81-47521")["bizNumber"] == "1208147521", "사업자번호 인식")
expect(ScanParser.parseBiz(text: "120-81-47522").isEmpty, "검증 실패한 사업자번호는 버림")
expect(ScanParser.parseLicense(text: "11-22-333333-44")["license"] == "112233333344", "면허번호 인식")

print("\n추가분까지 전부 통과")

print("[행정구역]")
expect(Regions.provinces.count == 16, "광역자치단체 16개 (실제 \(Regions.provinces.count)개)")
expect(Regions.provinces.contains("전남광주통합특별시"), "2026년 통합된 전남광주통합특별시 포함")
expect(!Regions.provinces.contains("광주광역시"), "통합으로 없어진 광주광역시는 빠짐")
expect(!Regions.provinces.contains("전라남도"), "통합으로 없어진 전라남도는 빠짐")
expect(Regions.districts(of: "서울특별시").count == 25, "서울 25개 자치구")
expect(Regions.districts(of: "인천광역시").contains("제물포구"), "인천 개편 반영 — 제물포구")
expect(!Regions.districts(of: "인천광역시").contains("중구"), "인천 중구는 폐지되어 빠짐")
expect(Regions.districts(of: "세종특별자치시").isEmpty, "세종은 하위 자치단체 없음")
expect(Regions.districts(of: "전남광주통합특별시").contains("무안군"), "무안군 포함")
expect(Regions.search("성", in: Regions.districts(of: "서울특별시")).contains("성동구"), "'성' → 성동구")
expect(Regions.search("ㄱㄴ", in: Regions.districts(of: "서울특별시")).contains("강남구"), "초성 'ㄱㄴ' → 강남구")

print("\n행정구역까지 전부 통과")

print("[날짜]")
expect(DateFormat.display("20250331") == "2025.03.31", "8자리 → 2025.03.31")
expect(DateFormat.display("2025.03.31") == "2025.03.31", "점을 찍어 넣어도 같은 결과")
expect(DateFormat.display("202503") == "2025.03", "6자리 → 2025.03")
expect(DateFormat.display("2025") == "2025", "짧으면 그대로")
expect(DateFormat.isPlausible("20250331"), "정상 날짜")
expect(!DateFormat.isPlausible("20251331"), "13월 거부")
expect(!DateFormat.isPlausible("20250332"), "32일 거부")

print("\n날짜까지 전부 통과")
