import SwiftUI
import VisionKit
import Vision

/// 카메라로 찍어서 글자를 읽어오는 화면.
/// 인식은 전부 기기 안에서(Vision) 처리하고, **찍은 사진은 저장하지 않는다.**
/// 텍스트를 뽑은 뒤 이미지는 메모리에서 그대로 버린다.
struct ScanView: UIViewControllerRepresentable {
    var onResult: ([String]) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: ScanView
        init(_ parent: ScanView) { self.parent = parent }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            var lines: [String] = []
            for i in 0..<scan.pageCount {
                lines += TextRecognizer.lines(in: scan.imageOfPage(at: i))
            }
            controller.dismiss(animated: true)
            parent.onResult(lines)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            controller.dismiss(animated: true)
        }
    }
}

enum TextRecognizer {
    /// 이미지에서 글자를 줄 단위로 읽는다. 전부 온디바이스 처리다.
    static func lines(in image: UIImage) -> [String] {
        guard let cg = image.cgImage else { return [] }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false   // 번호를 다루므로 자동 교정이 오히려 방해된다
        request.recognitionLanguages = ["ko-KR", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        try? handler.perform([request])

        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    }
}

/// 이 기기에서 문서 스캐너를 쓸 수 있는지
enum ScanAvailability {
    static var isSupported: Bool { VNDocumentCameraViewController.isSupported }
}
