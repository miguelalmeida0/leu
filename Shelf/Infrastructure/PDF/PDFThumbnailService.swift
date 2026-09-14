import PDFKit

/// Bounded thumbnail cache. The actor serializes access to its independent PDFDocument instances.
actor PDFThumbnailService {
    private var lastURL: URL?
    private var document: PDFDocument?
    private let cache = NSCache<NSString, NSData>()
    init() { cache.totalCostLimit = 16 * 1_024 * 1_024; cache.countLimit = 80 }
    func thumbnail(url: URL, pageIndex: Int, width: Int = 420) throws -> Data? {
        try Task.checkCancellation()
        let key = "\(url.path)-\(pageIndex)-\(width)" as NSString
        if let cached = cache.object(forKey: key) { return cached as Data }
        if lastURL != url { document = PDFDocument(url: url); lastURL = url }
        guard let page = document?.page(at: pageIndex) else { return nil }
        let data = autoreleasepool {
            page.thumbnail(of: CGSize(width: width, height: Int(Double(width) * 1.42)), for: .cropBox)
                .jpegData(compressionQuality: 0.82)
        }
        if let data { cache.setObject(data as NSData, forKey: key, cost: data.count) }
        return data
    }
}
