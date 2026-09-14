import XCTest
import PDFKit
import UIKit
import ShelfCore
@testable import Shelf

/// Apple-SDK geometry assertions. These inspect the actual PDFView conversion, not a page label.
final class PDFViewportGeometryTests: XCTestCase {
    @MainActor
    func testMixedSizePagesFitInsideTheSameViewport() async throws {
        let rig = try makeRig()
        defer { rig.window.isHidden = true; rig.viewport.detach() }
        await afterMainQueueTurn()
        for index in 0..<rig.document.pageCount {
            rig.controller.go(to: index)
            rig.controller.applyReadingScale(1)
            rig.viewport.layoutIfNeeded()
            let page = try XCTUnwrap(rig.document.page(at: index))
            let rect = rig.controller.view.convert(page.bounds(for: .cropBox), from: page)
            let bounds = rig.controller.view.bounds.insetBy(dx: -2, dy: -2)
            XCTAssertTrue(bounds.contains(rect), "Page \(index) clips at fit: \(rect) vs \(bounds)")
            XCTAssertEqual(rig.controller.currentPosition()?.pageIndex, index)
            XCTAssertEqual(rig.controller.view.displayMode, .singlePage)
        }
    }

    @MainActor
    func testUnchangedSwiftUIUpdateDoesNotUndoUserZoom() async throws {
        let rig = try makeRig()
        defer { rig.window.isHidden = true; rig.viewport.detach() }
        await afterMainQueueTurn()
        rig.controller.go(to: 1)
        rig.controller.applyReadingScale(1)
        let fit = rig.controller.zoom.fitScale
        XCTAssertGreaterThan(fit, 0)
        rig.controller.view.scaleFactor = fit * 1.4
        rig.controller.zoom.observedScaleChange()
        rig.controller.zoom.applyIfNeeded()
        XCTAssertEqual(rig.controller.view.scaleFactor / fit, 1.4, accuracy: 0.02)
        XCTAssertFalse(rig.controller.isAtFitScale())
    }

    @MainActor
    func testResizeRefitsOnePageWithoutChangingItsIdentity() async throws {
        let rig = try makeRig()
        defer { rig.window.isHidden = true; rig.viewport.detach() }
        await afterMainQueueTurn()
        rig.controller.go(to: 2)
        rig.viewport.frame.size = CGSize(width: 320, height: 480)
        rig.viewport.setNeedsLayout()
        rig.viewport.layoutIfNeeded()
        XCTAssertEqual(rig.controller.currentPosition()?.pageIndex, 2)
        XCTAssertTrue(rig.controller.isAtFitScale())
        let page = try XCTUnwrap(rig.document.page(at: 2))
        let rect = rig.controller.view.convert(page.bounds(for: .cropBox), from: page)
        XCTAssertTrue(rig.controller.view.bounds.insetBy(dx: -2, dy: -2).contains(rect))
    }

    @MainActor
    func testVerticalAndHorizontalModeChangesRetainPage() async throws {
        let rig = try makeRig()
        defer { rig.window.isHidden = true; rig.viewport.detach() }
        await afterMainQueueTurn()
        rig.controller.go(to: 1)
        rig.viewport.update(flow: .vertical, surround: .dark, scale: 1, reduceMotion: true)
        rig.controller.go(to: 1)
        XCTAssertEqual(rig.controller.view.displayMode, .singlePageContinuous)
        XCTAssertEqual(rig.controller.currentPosition()?.pageIndex, 1)
        rig.viewport.update(flow: .horizontal, surround: .dark, scale: 1, reduceMotion: true)
        rig.controller.go(to: 1)
        XCTAssertEqual(rig.controller.view.displayMode, .singlePage)
        XCTAssertEqual(rig.controller.currentPosition()?.pageIndex, 1)
    }

    @MainActor
    private func afterMainQueueTurn() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

    @MainActor
    private func makeRig() throws -> (window: UIWindow, viewport: PDFPagingViewport,
                                     controller: PDFSessionController, document: PDFDocument) {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        let data = renderer.pdfData { context in
            for (index, size) in [CGSize(width: 595, height: 842), CGSize(width: 350, height: 900),
                                  CGSize(width: 842, height: 595)].enumerated() {
                context.beginPage(withBounds: CGRect(origin: .zero, size: size), pageInfo: [:])
                ("Geometry page \(index + 1)" as NSString).draw(at: CGPoint(x: 20, y: 20),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 22), .foregroundColor: UIColor.black])
            }
        }
        let document = try XCTUnwrap(PDFDocument(data: data))
        let controller = PDFSessionController()
        let viewport = PDFPagingViewport(controller: controller)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let root = UIViewController()
        root.view.backgroundColor = .black
        window.rootViewController = root
        window.makeKeyAndVisible()
        viewport.frame = CGRect(x: 0, y: 60, width: 390, height: 650)
        root.view.addSubview(viewport)
        viewport.update(flow: .horizontal, surround: .dark, scale: 1, reduceMotion: true)
        controller.install(document, marks: [], position: ReadingPosition())
        viewport.setNeedsLayout()
        viewport.layoutIfNeeded()
        return (window, viewport, controller, document)
    }
}
