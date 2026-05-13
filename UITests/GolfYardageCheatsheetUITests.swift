import XCTest

final class GolfYardageCheatsheetUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testFirstLaunchCreatesProfileAndOpensAddClubFlow() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset-data"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Create Profile"].waitForExistence(timeout: 5))

        let nameField = app.textFields["profile-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))

        let createButton = app.buttons["create-profile-button"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 2))
        XCTAssertFalse(createButton.isEnabled)

        nameField.tap()
        nameField.typeText("Rod")
        XCTAssertTrue(createButton.isEnabled)
        createButton.tap()

        XCTAssertTrue(app.navigationBars["Add Club"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["club-form"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Finish"].exists)
        XCTAssertTrue(app.buttons["Save & Add Another"].exists)
    }
}
