import SwiftUI
import CoreImage.CIFilterBuiltins

/// 와이파이 QR — 손님에게 화면만 보여주면 접속된다.
struct WiFiQRView: View {
    let ssid: String
    let password: String
    let security: String

    var body: some View {
        VStack(spacing: 10) {
            if let image = qrImage {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 200, height: 200)
            }
            Text(ssid).font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    /// 표준 Wi-Fi QR 문자열. 특수문자는 이스케이프해야 파싱이 깨지지 않는다.
    private var payload: String {
        let type = security.uppercased().contains("WEP") ? "WEP"
            : (security.isEmpty || security.contains("없") ? "nopass" : "WPA")
        return "WIFI:T:\(type);S:\(escape(ssid));P:\(escape(password));;"
    }

    private func escape(_ s: String) -> String {
        var out = ""
        for ch in s {
            if #"\;,:""#.contains(ch) { out.append("\\") }
            out.append(ch)
        }
        return out
    }

    private var qrImage: UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let ctx = CIContext()
        guard let cg = ctx.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
