import XCTest

final class OptiqOCRTests: XCTestCase {
  func testImportedPhotoRecognizesTextAndSavesPDF() {
    let expectedText = "OPTIQ OCR SAMPLE 4827"
    let app = XCUIApplication()
    app.launch()

    let importImage = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Import image")).firstMatch
    XCTAssertTrue(importImage.waitForExistence(timeout: 60))
    let pdfs = app.otherElements.matching(NSPredicate(format: "label BEGINSWITH %@ AND label ENDSWITH %@", expectedText + "_", ".pdf"))
    let existingLabels = Set(pdfs.allElementsBoundByIndex.map(\.label))
    importImage.tap()

    // Import the sample as the most recent photo before running.
    let photo = app.images.matching(NSPredicate(format: "label BEGINSWITH %@", "Photo,")).firstMatch
    guard photo.waitForExistence(timeout: 75) else {
      return XCTFail("The photo picker did not show the sample.\n\(app.debugDescription)")
    }
    photo.tap()

    let save = app.buttons["Save PDF"]
    XCTAssertTrue(save.waitForExistence(timeout: 60), app.debugDescription)
    XCTAssertEqual(app.textFields.firstMatch.value as? String, expectedText)
    save.tap()

    let newPDF = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      pdfs.allElementsBoundByIndex.contains { !existingLabels.contains($0.label) }
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [newPDF], timeout: 30), .completed, app.debugDescription)
    guard let savedLabel = pdfs.allElementsBoundByIndex.map(\.label).first(where: { !existingLabels.contains($0) }) else {
      return XCTFail("The newly saved PDF was not listed.")
    }
    app.terminate()
    app.launch()
    XCTAssertTrue(app.otherElements.matching(NSPredicate(format: "label == %@", savedLabel))
      .firstMatch.waitForExistence(timeout: 60), "The saved document should persist across launches.")
  }
}
