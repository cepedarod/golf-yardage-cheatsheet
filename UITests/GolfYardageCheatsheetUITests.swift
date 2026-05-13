import XCTest

@MainActor
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

        saveClub(fullDistance: "255", shouldAddAnother: true, in: app)

        XCTAssertTrue(app.navigationBars["Add Club"].waitForExistence(timeout: 5))
        let fullDistanceField = app.textFields["full-distance-field"]
        XCTAssertTrue(fullDistanceField.waitForExistence(timeout: 2))
        XCTAssertEqual(fullDistanceField.value as? String, "Yards")

        saveClub(fullDistance: "230", shouldAddAnother: false, in: app)

        XCTAssertTrue(app.navigationBars["Distance"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Driver"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["3 Wood"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["255"].exists)
        XCTAssertTrue(app.staticTexts["230"].exists)
    }

    func testTargetYardageShowsOnlyTwoClosestMatches() {
        let app = launchFreshApp()
        createProfile(named: "Rod", in: app)

        saveClub(fullDistance: "255", shouldAddAnother: true, in: app)
        saveClub(fullDistance: "230", shouldAddAnother: true, in: app)
        saveClub(fullDistance: "215", shouldAddAnother: false, in: app)

        XCTAssertTrue(app.navigationBars["Distance"].waitForExistence(timeout: 5))

        let targetField = app.textFields["target-yardage-field"]
        XCTAssertTrue(targetField.waitForExistence(timeout: 2))
        targetField.tap()
        app.keys["2"].tap()
        app.keys["3"].tap()
        app.keys["2"].tap()
        app.buttons["Done"].tap()

        XCTAssertTrue(app.buttons["Clear"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["closest-match-3 Wood"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["closest-match-5 Wood"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["3 Wood"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["5 Wood"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Full 230"].exists)
        XCTAssertTrue(app.staticTexts["Full 215"].exists)
        XCTAssertFalse(app.staticTexts["Driver"].exists)
        XCTAssertFalse(app.staticTexts["Full 255"].exists)
    }

    func testTargetYardageAutoClearsAfterDelay() {
        let app = launchFreshApp(environment: ["TARGET_YARDAGE_CLEAR_DELAY_NANOSECONDS": "5000000000"])
        createProfile(named: "Rod", in: app)

        saveClub(fullDistance: "255", shouldAddAnother: false, in: app)

        XCTAssertTrue(app.navigationBars["Distance"].waitForExistence(timeout: 5))
        enterTargetYardage("255", in: app)

        let clearButton = app.buttons["Clear"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: 2))

        let targetCleared = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: clearButton)
        wait(for: [targetCleared], timeout: 8)

        let targetField = app.textFields["target-yardage-field"]
        XCTAssertEqual(targetField.value as? String, "Yards")
        XCTAssertTrue(app.descendants(matching: .any)["club-row-Driver"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["255"].exists)
    }

    func testPunchFilterShowsOnlyPunchClubs() {
        let app = launchFreshApp()
        createProfile(named: "Rod", in: app)

        saveClub(fullDistance: "255", shouldAddAnother: true, in: app)

        XCTAssertTrue(app.navigationBars["Add Club"].waitForExistence(timeout: 5))
        app.buttons["shot-type-punch"].tap()
        saveClub(fullDistance: "230", shouldAddAnother: false, in: app)

        XCTAssertTrue(app.navigationBars["Distance"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Driver"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["3 Wood (Punch)"].waitForExistence(timeout: 2))

        app.buttons["shot-filter-punch"].tap()

        XCTAssertTrue(app.staticTexts["3 Wood (Punch)"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["230"].exists)
        XCTAssertFalse(app.staticTexts["Driver"].exists)
        XCTAssertFalse(app.staticTexts["255"].exists)

        app.buttons["shot-filter-all"].tap()

        XCTAssertTrue(app.staticTexts["Driver"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["3 Wood (Punch)"].exists)
    }

    func testDashboardEditUpdatesExistingClubDistance() {
        let app = launchFreshApp()
        createProfile(named: "Rod", in: app)

        saveClub(fullDistance: "255", shouldAddAnother: false, in: app)

        XCTAssertTrue(app.navigationBars["Distance"].waitForExistence(timeout: 5))
        let driverRow = app.descendants(matching: .any)["club-row-Driver"]
        XCTAssertTrue(driverRow.waitForExistence(timeout: 2))
        driverRow.swipeRight()
        app.buttons["Edit"].tap()

        XCTAssertTrue(app.navigationBars["Edit Club"].waitForExistence(timeout: 5))
        let fullDistanceField = app.textFields["full-distance-field"]
        XCTAssertEqual(fullDistanceField.value as? String, "255")

        replaceText(in: fullDistanceField, with: "260", in: app)
        app.buttons["save-club-button"].tap()

        XCTAssertTrue(app.navigationBars["Distance"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Driver"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["260"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["255"].exists)
    }

    private func launchFreshApp(environment: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset-data"]
        app.launchEnvironment = environment
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

    private func enterTargetYardage(_ yardage: String, in app: XCUIApplication) {
        let targetField = app.textFields["target-yardage-field"]
        XCTAssertTrue(targetField.waitForExistence(timeout: 2))
        targetField.tap()

        for digit in yardage {
            app.keys[String(digit)].tap()
        }

        app.buttons["Done"].tap()
    }

    private func replaceText(in textField: XCUIElement, with text: String, in app: XCUIApplication) {
        XCTAssertTrue(textField.waitForExistence(timeout: 2))
        textField.tap()
        textField.press(forDuration: 1)

        if app.menuItems["Select All"].waitForExistence(timeout: 1) {
            app.menuItems["Select All"].tap()
        } else if let value = textField.value as? String {
            textField.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
            for _ in value.filter(\.isNumber) {
                app.keys["delete"].tap()
            }
        }

        textField.typeText(text)
    }

    private func saveClub(fullDistance: String, shouldAddAnother: Bool, in app: XCUIApplication) {
        enterFullDistance(fullDistance, in: app)

        if shouldAddAnother {
            app.buttons["save-and-add-another-button"].tap()
        } else {
            app.buttons["finish-club-button"].tap()
        }
    }
}
