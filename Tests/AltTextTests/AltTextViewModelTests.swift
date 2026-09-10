import XCTest
@testable import AltText

@MainActor
final class AltTextViewModelTests: XCTestCase {
    func testAddImagesAppendsNewPendingItems() {
        let viewModel = AltTextViewModel(service: FakeAltTextService())

        viewModel.addImages(at: [URL(fileURLWithPath: "/tmp/a.jpg"), URL(fileURLWithPath: "/tmp/b.jpg")])

        XCTAssertEqual(viewModel.items.count, 2)
        XCTAssertTrue(viewModel.items.allSatisfy { $0.status == .pending })
    }

    func testAddImagesSkipsDuplicateURLs() {
        let viewModel = AltTextViewModel(service: FakeAltTextService())
        let url = URL(fileURLWithPath: "/tmp/a.jpg")

        viewModel.addImages(at: [url])
        viewModel.addImages(at: [url])

        XCTAssertEqual(viewModel.items.count, 1)
    }

    func testGenerateAltTextMarksAllPendingItemsDoneWithServiceResult() async {
        let service = FakeAltTextService(result: .success("generated text"))
        let viewModel = AltTextViewModel(service: service)
        viewModel.addImages(at: [URL(fileURLWithPath: "/tmp/a.jpg"), URL(fileURLWithPath: "/tmp/b.jpg")])
        viewModel.modelAvailability = .ready

        await viewModel.generateAltText()

        XCTAssertEqual(viewModel.items.count, 2)
        XCTAssertTrue(viewModel.items.allSatisfy { $0.status == .done("generated text") })
        XCTAssertFalse(viewModel.isGenerating)
        XCTAssertEqual(service.generatedCount, 2)
    }

    func testGenerateAltTextDoesNothingWhenModelUnavailable() async {
        let service = FakeAltTextService(result: .success("generated text"))
        let viewModel = AltTextViewModel(service: service)
        viewModel.addImages(at: [URL(fileURLWithPath: "/tmp/a.jpg")])
        viewModel.modelAvailability = .unavailable("Nope.")

        await viewModel.generateAltText()

        XCTAssertEqual(viewModel.items.first?.status, .pending)
        XCTAssertEqual(service.generatedCount, 0)
    }

    func testGenerateAltTextMarksFailedItemsWithErrorMessage() async {
        let service = FakeAltTextService(result: .failure(TestError.failure))
        let viewModel = AltTextViewModel(service: service)
        viewModel.addImages(at: [URL(fileURLWithPath: "/tmp/a.jpg")])
        viewModel.modelAvailability = .ready

        await viewModel.generateAltText()

        guard case .failed = viewModel.items.first?.status else {
            return XCTFail("Expected a failed status, got \(String(describing: viewModel.items.first?.status))")
        }
    }

    func testRemoveImageDeletesItem() {
        let viewModel = AltTextViewModel(service: FakeAltTextService())
        viewModel.addImages(at: [URL(fileURLWithPath: "/tmp/a.jpg")])
        let id = viewModel.items[0].id

        viewModel.removeImage(id: id)

        XCTAssertTrue(viewModel.items.isEmpty)
    }

    func testSetAltTextUpdatesDoneStatus() {
        let viewModel = AltTextViewModel(service: FakeAltTextService())
        viewModel.addImages(at: [URL(fileURLWithPath: "/tmp/a.jpg")])
        let id = viewModel.items[0].id

        viewModel.setAltText("edited text", for: id)

        XCTAssertEqual(viewModel.altText(for: id), "edited text")
    }
}

private enum TestError: LocalizedError {
    case failure

    var errorDescription: String? { "Generation failed." }
}

private final class FakeAltTextService: AltTextGenerating, @unchecked Sendable {
    let result: Result<String, Error>
    private(set) var generatedCount = 0

    init(result: Result<String, Error> = .success("stub")) {
        self.result = result
    }

    func availability() -> ModelAvailabilityState { .ready }
    func prewarm() {}

    func generateAltText(for item: ImageItem) async throws -> String {
        generatedCount += 1
        return try result.get()
    }
}
