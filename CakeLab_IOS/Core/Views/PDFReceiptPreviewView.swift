import PDFKit
import SwiftUI

// MARK: - PDF Receipt Preview View
struct PDFReceiptPreviewView: View {
    let receipt: PDFReceiptData
    @Environment(\.dismiss) private var dismiss

    private var pdfData: Data {
        PDFReceiptRenderer.makePDF(from: receipt)
    }

    var body: some View {
        NavigationStack {
            PDFKitView(data: pdfData)
                .navigationTitle("Payment Receipt")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") { dismiss() }
                            .foregroundColor(.cakeBrown)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(
                            item: PDFReceiptTransferable(receipt: receipt),
                            preview: SharePreview(receipt.fileName)
                        )
                            .foregroundColor(.cakeBrown)
                    }
                }
        }
    }
}

// MARK: - PDFKit UIViewRepresentable
private struct PDFKitView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .white
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = PDFDocument(data: data)
    }
}
