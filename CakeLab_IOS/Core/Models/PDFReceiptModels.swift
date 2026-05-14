import UniformTypeIdentifiers
import CoreTransferable

struct PDFReceiptData: Identifiable {
    let id: String
    let title: String
    let receiptNumber: String
    let cakeName: String
    let payerLabel: String
    let payerName: String
    let receiverLabel: String
    let receiverName: String
    let paymentMethod: String
    let status: String
    let paidAt: Date
    let subtotalLabel: String
    let subtotal: Double
    let serviceFee: Double
    let totalLabel: String
    let total: Double

    var fileName: String {
        let raw = "\(cakeName)-\(receiptNumber)"
        let allowed = CharacterSet.alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn: "-_"))
        let sanitized = raw.unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "-" }
        let collapsed = String(sanitized)
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
        return (collapsed.isEmpty ? "CakeLab_Receipt" : collapsed) + ".pdf"
    }
}

struct PDFReceiptTransferable: Transferable {
    let receipt: PDFReceiptData

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .pdf) { item in
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(item.receipt.fileName)
            try PDFReceiptRenderer.makePDF(from: item.receipt).write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}
