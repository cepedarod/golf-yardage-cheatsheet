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
        XCTAssertTrue(app.staticTexts["3/4"].exists)
        XCTAssertTrue(app.staticTexts["Half"].exists)
        XCTAssertTrue(app.staticTexts["Quarter"].exists)
        XCTAssertTrue(app.staticTexts["-"].exists)
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
        XCTAssertTrue(app.descendants(matching: .any)["closest-match-Driver"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["3 Wood"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Driver"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Full 230"].exists)
        XCTAssertTrue(app.staticTexts["Full 255"].exists)
        XCTAssertFalse(app.staticTexts["5 Wood"].exists)
        XCTAssertFalse(app.staticTexts["Full 215"].exists)
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

    func testLowTrajectoryFilterShowsOnlyLowTrajectoryClubs() {
        let app = launchFreshApp()
        createProfile(named: "Rod", in: app)

        saveClub(fullDistance: "255", shouldAddAnother: true, in: app)

        XCTAssertTrue(app.navigationBars["Add Club"].waitForExistence(timeout: 5))
        app.buttons["distance-category-low-trajectory"].tap()

        let lowStingerDistanceField = app.textFields["low-stinger-distance-field"]
        XCTAssertTrue(lowStingerDistanceField.waitForExistence(timeout: 2))
        lowStingerDistanceField.tap()
        lowStingerDistanceField.typeText("230")
        app.buttons["finish-club-button"].tap()

        XCTAssertTrue(app.navigationBars["Distance"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Driver"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["3 Wood (Low Trajectory)"].exists)

        app.buttons["shot-filter-low-trajectory"].tap()

        XCTAssertTrue(app.staticTexts["3 Wood (Low Trajectory)"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["230"].exists)
        XCTAssertFalse(app.staticTexts["Driver"].exists)
        XCTAssertFalse(app.staticTexts["255"].exists)

        app.buttons["shot-filter-normal"].tap()

        XCTAssertTrue(app.staticTexts["Driver"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["3 Wood (Low Trajectory)"].exists)
    }

    func testRecordShotUpdatesRealDistanceMode() {
        let app = launchFreshApp()
        createProfile(named: "Rod", in: app)

        saveClub(fullDistance: "255", shouldAddAnother: false, in: app)

        XCTAssertTrue(app.navigationBars["Distance"].waitForExistence(timeout: 5))
        let recordShotButton = app.buttons["record-shot-button"]
        XCTAssertTrue(recordShotButton.waitForExistence(timeout: 2))
        recordShotButton.tap()

        XCTAssertTrue(app.navigationBars["Record Shot"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["record-shot-form"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Driver"].waitForExistence(timeout: 2))

        let shotDistanceField = app.textFields["record-shot-distance-field"]
        XCTAssertTrue(shotDistanceField.waitForExistence(timeout: 2))
        shotDistanceField.tap()
        shotDistanceField.typeText("250")
        app.buttons["Done"].tap()
        app.buttons["save-shot-button"].tap()

        XCTAssertTrue(app.navigationBars["Distance"].waitForExistence(timeout: 5))
        app.buttons["value-mode-real"].tap()

        XCTAssertTrue(app.staticTexts["250"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["255"].exists)
    }

    func testAnalysisTabShowsRecordedClubStats() {
        let app = launchFreshApp()
        createProfile(named: "Rod", in: app)

        saveClub(fullDistance: "255", shouldAddAnother: false, in: app)

        XCTAssertTrue(app.navigationBars["Distance"].waitForExistence(timeout: 5))
        let recordShotButton = app.buttons["record-shot-button"]
        XCTAssertTrue(recordShotButton.waitForExistence(timeout: 2))
        recordShotButton.tap()

        XCTAssertTrue(app.navigationBars["Record Shot"].waitForExistence(timeout: 5))
        let shotDistanceField = app.textFields["record-shot-distance-field"]
        XCTAssertTrue(shotDistanceField.waitForExistence(timeout: 2))
        shotDistanceField.tap()
        shotDistanceField.typeText("250")
        app.buttons["Done"].tap()
        app.buttons["save-shot-button"].tap()

        XCTAssertTrue(app.navigationBars["Distance"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Analysis"].tap()

        XCTAssertTrue(app.navigationBars["Analysis"].waitForExistence(timeout: 5))
        let driverAnalysisRow = app.descendants(matching: .any)["analysis-club-row-Driver"]
        XCTAssertTrue(driverAnalysisRow.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["1 recorded shot"].exists)
        driverAnalysisRow.tap()

        XCTAssertTrue(app.navigationBars["Driver"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["analysis-distance-full"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["255"].exists)
        XCTAssertTrue(app.staticTexts["250"].exists)

        let totalShots = app.staticTexts["analysis-total-shots"]
        XCTAssertTrue(totalShots.waitForExistence(timeout: 2))
        XCTAssertEqual(totalShots.label, "1 shot")

        app.swipeUp()

        XCTAssertTrue(app.staticTexts["Pure"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["analysis-percentage-Straight"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["100%"].exists)
    }

    func testAnalysisShotLogSupportsEditingAndDeletingShot() {
        let app = launchFreshApp()
        createProfile(named: "Rod", in: app)

        saveClub(fullDistance: "255", shouldAddAnother: false, in: app)

        XCTAssertTrue(app.navigationBars["Distance"].waitForExistence(timeout: 5))
        let recordShotButton = app.buttons["record-shot-button"]
        XCTAssertTrue(recordShotButton.waitForExistence(timeout: 2))
        recordShotButton.tap()

        XCTAssertTrue(app.navigationBars["Record Shot"].waitForExistence(timeout: 5))
        let shotDistanceField = app.textFields["record-shot-distance-field"]
        XCTAssertTrue(shotDistanceField.waitForExistence(timeout: 2))
        shotDistanceField.tap()
        shotDistanceField.typeText("250")
        app.buttons["Done"].tap()
        app.buttons["save-shot-button"].tap()

        XCTAssertTrue(app.navigationBars["Distance"].waitForExistence(timeout: 5))
        app.buttons["record-shot-button"].tap()

        XCTAssertTrue(app.navigationBars["Record Shot"].waitForExistence(timeout: 5))
        let stingerButton = app.buttons["shot-power-low-trajectory-stinger"]
        XCTAssertTrue(stingerButton.waitForExistence(timeout: 2))
        stingerButton.tap()
        let stingerDistanceField = app.textFields["record-shot-distance-field"]
        XCTAssertTrue(stingerDistanceField.waitForExistence(timeout: 2))
        stingerDistanceField.tap()
        stingerDistanceField.typeText("230")
        app.buttons["Done"].tap()
        app.buttons["save-shot-button"].tap()

        XCTAssertTrue(app.navigationBars["Distance"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Analysis"].tap()

        XCTAssertTrue(app.navigationBars["Analysis"].waitForExistence(timeout: 5))
        let driverAnalysisRow = app.descendants(matching: .any)["analysis-club-row-Driver"]
        XCTAssertTrue(driverAnalysisRow.waitForExistence(timeout: 2))
        driverAnalysisRow.tap()

        XCTAssertTrue(app.navigationBars["Driver"].waitForExistence(timeout: 5))
        let totalShots = app.staticTexts["analysis-total-shots"]
        XCTAssertTrue(totalShots.waitForExistence(timeout: 2))
        XCTAssertEqual(totalShots.label, "2 shots")

        let totalShotsRow = app.descendants(matching: .any)["analysis-total-shots-row"]
        XCTAssertTrue(totalShotsRow.waitForExistence(timeout: 2))
        totalShotsRow.tap()

        XCTAssertTrue(app.navigationBars["Recorded Shots"].waitForExistence(timeout: 5))
        let shotRow = app.descendants(matching: .any)["shot-record-row-full"]
        XCTAssertTrue(shotRow.waitForExistence(timeout: 2))
        let stingerRow = app.descendants(matching: .any)["shot-record-row-stinger"]
        XCTAssertTrue(stingerRow.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Full"].exists)
        XCTAssertTrue(app.staticTexts["Stinger"].exists)
        XCTAssertFalse(app.staticTexts["Normal Full"].exists)
        XCTAssertFalse(app.staticTexts["Low Trajectory Stinger"].exists)
        XCTAssertLessThan(shotRow.frame.minY, stingerRow.frame.minY)
        XCTAssertTrue(app.staticTexts["250 yds"].exists)
        shotRow.tap()

        XCTAssertTrue(app.navigationBars["Edit Shot"].waitForExistence(timeout: 5))
        let editDistanceField = app.textFields["edit-shot-distance-field"]
        XCTAssertTrue(app.buttons["clear-edit-shot-distance-button"].waitForExistence(timeout: 2))
        app.buttons["clear-edit-shot-distance-button"].tap()
        editDistanceField.tap()
        editDistanceField.typeText("251")
        app.buttons["Done"].tap()
        app.buttons["save-shot-edit-button"].tap()

        XCTAssertTrue(app.navigationBars["Recorded Shots"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["251 yds"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["250 yds"].exists)

        let editedShotRow = app.descendants(matching: .any)["shot-record-row-full"]
        XCTAssertTrue(editedShotRow.waitForExistence(timeout: 2))
        editedShotRow.swipeLeft()

        let deleteButton = app.buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 2))
        deleteButton.tap()

        XCTAssertTrue(app.staticTexts["Stinger"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["251 yds"].exists)

        let remainingShotRow = app.descendants(matching: .any)["shot-record-row-stinger"]
        XCTAssertTrue(remainingShotRow.waitForExistence(timeout: 2))
        remainingShotRow.swipeLeft()

        XCTAssertTrue(deleteButton.waitForExistence(timeout: 2))
        deleteButton.tap()

        XCTAssertTrue(app.staticTexts["No Recorded Shots"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["230 yds"].exists)
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

    func testInactiveClubRestoreAndDeleteFlows() {
        let app = launchFreshApp()
        createProfile(named: "Rod", in: app)

        saveClub(fullDistance: "255", shouldAddAnother: true, in: app)
        saveClub(fullDistance: "230", shouldAddAnother: false, in: app)

        XCTAssertTrue(app.navigationBars["Distance"].waitForExistence(timeout: 5))
        deactivateClub(named: "Driver", in: app)

        openInactiveClubs(in: app)
        let inactiveDriverRow = app.descendants(matching: .any)["club-row-Driver"]
        XCTAssertTrue(inactiveDriverRow.waitForExistence(timeout: 2))
        inactiveDriverRow.swipeRight()

        let restoreButton = app.buttons["Restore"]
        XCTAssertTrue(restoreButton.waitForExistence(timeout: 2))
        restoreButton.tap()
        waitForDisappearance(of: inactiveDriverRow)

        app.navigationBars["Inactive Clubs"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Distance"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["club-row-Driver"].waitForExistence(timeout: 2))

        deactivateClub(named: "3 Wood", in: app)

        openInactiveClubs(in: app)
        let inactiveThreeWoodRow = app.descendants(matching: .any)["club-row-3 Wood"]
        XCTAssertTrue(inactiveThreeWoodRow.waitForExistence(timeout: 2))
        inactiveThreeWoodRow.swipeLeft()

        let deleteButton = app.buttons["Delete"]
        if deleteButton.waitForExistence(timeout: 1) {
            deleteButton.tap()
        }

        let confirmDeleteButton = app.buttons["Delete Club"]
        XCTAssertTrue(confirmDeleteButton.waitForExistence(timeout: 2))
        confirmDeleteButton.tap()
        XCTAssertTrue(app.staticTexts["No Inactive Clubs"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.descendants(matching: .any)["club-row-3 Wood"].exists)
    }

    func testSavedBagPersistsAcrossRelaunch() {
        let app = launchFreshApp()
        createProfile(named: "Rod", in: app)

        saveClub(fullDistance: "255", shouldAddAnother: true, in: app)
        saveClub(fullDistance: "230", shouldAddAnother: false, in: app)

        XCTAssertTrue(app.navigationBars["Distance"].waitForExistence(timeout: 5))
        deactivateClub(named: "3 Wood", in: app)
        app.terminate()

        let relaunchedApp = launchAppPreservingData()
        XCTAssertTrue(relaunchedApp.navigationBars["Distance"].waitForExistence(timeout: 5))
        XCTAssertTrue(relaunchedApp.descendants(matching: .any)["club-row-Driver"].waitForExistence(timeout: 2))
        XCTAssertTrue(relaunchedApp.staticTexts["255"].exists)
        XCTAssertFalse(relaunchedApp.descendants(matching: .any)["club-row-3 Wood"].exists)

        openInactiveClubs(in: relaunchedApp)
        XCTAssertTrue(relaunchedApp.descendants(matching: .any)["club-row-3 Wood"].waitForExistence(timeout: 2))
        XCTAssertTrue(relaunchedApp.staticTexts["230"].exists)
    }

    private func launchFreshApp(environment: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset-data"]
        app.launchEnvironment = environment
        app.launch()
        return app
    }

    private func launchAppPreservingData(environment: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
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

    private func deactivateClub(named displayName: String, in app: XCUIApplication) {
        let clubRow = app.descendants(matching: .any)["club-row-\(displayName)"]
        XCTAssertTrue(clubRow.waitForExistence(timeout: 2))
        clubRow.swipeLeft()

        let deactivateButton = app.buttons["Deactivate"]
        if deactivateButton.waitForExistence(timeout: 1) {
            deactivateButton.tap()
        }

        waitForDisappearance(of: clubRow)
    }

    private func openInactiveClubs(in app: XCUIApplication) {
        let inactiveClubsButton = app.buttons["Inactive Clubs"]
        XCTAssertTrue(inactiveClubsButton.waitForExistence(timeout: 2))
        inactiveClubsButton.tap()
        XCTAssertTrue(app.navigationBars["Inactive Clubs"].waitForExistence(timeout: 5))
    }

    private func waitForDisappearance(of element: XCUIElement, timeout: TimeInterval = 2) {
        let expectation = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        wait(for: [expectation], timeout: timeout)
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
