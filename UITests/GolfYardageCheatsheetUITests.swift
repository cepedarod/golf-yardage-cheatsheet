import XCTest

final class GolfYardageCheatsheetUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testFirstLaunchCreatesProfileAndOpensAddClubFlow() {
        let app = launchFreshApp()

        createProfile(named: "Rod", in: app)

        XCTAssertTrue(app.navigationBars["Add Club"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["club-form"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["finish-club-button"].exists)
        XCTAssertTrue(app.buttons["save-and-add-another-button"].exists)
    }

    func testAddClubWithFinishShowsClubOnDashboard() {
        let app = launchFreshApp()
        createProfile(named: "Rod", in: app)

        enterFullDistance("255", in: app)
        app.buttons["finish-club-button"].tap()

        XCTAssertTrue(app.navigationBars["Distance"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Driver"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["255"].waitForExistence(timeout: 2))
    }

    func testSaveAndAddAnotherCreatesMultipleClubs() {
        let app = launchFreshApp()
        createProfile(named: "Rod", in: app)

        enterFullDistance("255", in: app)
        app.buttons["save-and-add-another-button"].tap()

        XCTAssertTrue(app.navigationBars["Add Club"].waitForExistence(timeout: 5))
        let fullDistanceField = app.textFields["full-distance-field"]
        XCTAssertTrue(fullDistanceField.waitForExistence(timeout: 2))
        XCTAssertEqual(fullDistanceField.value as? String, "Yards")

        enterFullDistance("230", in: app)
        app.buttons["finish-club-button"].tap()

        XCTAssertTrue(app.navigationBars["Distance"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Driver"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["3 Wood"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["255"].exists)
        XCTAssertTrue(app.staticTexts["230"].exists)
    }

    private func launchFreshApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset-data"]
        app.launch()
        return app
    }

    private func createProfile(named name: String, in app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars["Create Profile"].waitForExistence(timeout: 5))

        let nameField = app.textFields["profile-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))

        let createButton = app.buttons["create-profile-button"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 2))
        XCTAssertFalse(createButton.isEnabled)

        nameField.tap()
        nameField.typeText(name)
        XCTAssertTrue(createButton.isEnabled)
        createButton.tap()
    }

    private func enterFullDistance(_ distance: String, in app: XCUIApplication) {
        let fullDistanceField = app.textFields["full-distance-field"]
        XCTAssertTrue(fullDistanceField.waitForExistence(timeout: 2))
        fullDistanceField.tap()
        fullDistanceField.typeText(distance)
    }
}
