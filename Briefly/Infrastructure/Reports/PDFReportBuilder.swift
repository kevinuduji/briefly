import Foundation
import PDFKit
import UIKit

enum PDFReportBuilder {
    static func buildDailyRecap(title: String, body: String) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let format = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            let titleFont = UIFont.systemFont(ofSize: 22, weight: .semibold)
            let bodyFont = UIFont.systemFont(ofSize: 13, weight: .regular)

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.label,
            ]
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: bodyFont,
                .foregroundColor: UIColor.label,
            ]

            (title as NSString).draw(in: CGRect(x: 48, y: 48, width: pageRect.width - 96, height: 40), withAttributes: titleAttributes)

            let paragraph = body
            let textRect = CGRect(x: 48, y: 110, width: pageRect.width - 96, height: pageRect.height - 160)
            (paragraph as NSString).draw(with: textRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: bodyAttributes, context: nil)
        }
        return data
    }
}
