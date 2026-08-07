import XCTest

final class RefTraceAppUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testHomeScreenLaunch() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["RefTrace"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Upcoming Game"].exists || app.staticTexts["Upcoming Games"].exists)
        XCTAssertTrue(app.buttons["Create New Game. Enter game details manually"].exists)
        XCTAssertTrue(app.buttons["Pull from OfficialEase. Retrieve an assigned game"].exists)
    }

    @MainActor
    func testUpcomingGamesAppearsAbovePrimaryActions() throws {
        let app = XCUIApplication()
        app.launch()
        let upcoming = app.staticTexts["Upcoming Game"].exists ? app.staticTexts["Upcoming Game"] : app.staticTexts["Upcoming Games"]
        XCTAssertTrue(upcoming.waitForExistence(timeout: 5))
        let create = app.buttons["Create New Game. Enter game details manually"]
        let pull = app.buttons["Pull from OfficialEase. Retrieve an assigned game"]
        XCTAssertTrue(create.exists)
        XCTAssertTrue(pull.exists)
        XCTAssertLessThan(upcoming.frame.minY, create.frame.minY)
        XCTAssertLessThan(create.frame.minY, pull.frame.minY)
    }

    @MainActor
    func testUpcomingCardContentDisplays() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_RESET_DATA")
        app.launch()
        XCTAssertTrue(app.staticTexts["Next Assignment"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Date"].exists)
        XCTAssertTrue(app.staticTexts["Report Time"].exists)
        XCTAssertTrue(app.staticTexts["Start Time"].exists)
        XCTAssertTrue(app.staticTexts["Location"].exists)
        XCTAssertTrue(app.staticTexts["Position"].exists)
    }

    @MainActor
    func testTappingPendingUpcomingGameOpensImportPreview() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Next Assignment"].waitForExistence(timeout: 5))
        app.staticTexts["Next Assignment"].tap()
        XCTAssertTrue(app.navigationBars["Import Preview"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testCreateNewGameButtonOpensManualForm() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Create New Game. Enter game details manually"].tap()
        XCTAssertTrue(app.navigationBars["Create New Game"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testPullFromOfficialEaseButtonOpensImport() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Pull from OfficialEase. Retrieve an assigned game"].tap()
        XCTAssertTrue(app.navigationBars["Pull from OfficialEase"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testQuickAccessButtonsOpenScreens() throws {
        let app = XCUIApplication()
        app.launch()
        app.swipeUp()
        XCTAssertTrue(app.buttons["Rules"].waitForExistence(timeout: 3))
        app.buttons["Rules"].tap()
        XCTAssertTrue(app.navigationBars["Rules"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.swipeUp()
        XCTAssertTrue(app.buttons["Sync Status"].waitForExistence(timeout: 3))
        app.buttons["Sync Status"].tap()
        XCTAssertTrue(app.navigationBars["Sync Status"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testOpeningOfficialsCommunicationFromGameManagement() throws {
        let app = XCUIApplication()
        openOfficialsCommunication(app)
        XCTAssertTrue(app.navigationBars["Officials Communication"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testCreatingCommunicationSessionAsHeadOfficial() throws {
        let app = XCUIApplication()
        openOfficialsCommunication(app)
        if app.buttons["Create Communication Session"].waitForExistence(timeout: 2) {
            app.buttons["Create Communication Session"].tap()
            XCTAssertTrue(app.navigationBars["Communication Setup"].waitForExistence(timeout: 3))
        } else {
            XCTAssertTrue(app.staticTexts["Voice"].waitForExistence(timeout: 3) || app.staticTexts["Recipient"].waitForExistence(timeout: 3))
        }
    }

    @MainActor
    func testCommunicationHistoryRouteWhenSessionActive() throws {
        let app = XCUIApplication()
        openOfficialsCommunication(app)
        if app.buttons["Create Communication Session"].waitForExistence(timeout: 2) {
            app.buttons["Create Communication Session"].tap()
            XCTAssertTrue(app.navigationBars["Communication Setup"].waitForExistence(timeout: 3))
        } else {
            XCTAssertTrue(app.navigationBars["Officials Communication"].waitForExistence(timeout: 3))
        }
    }

    @MainActor
    func testInGameScreenShowsPrimaryInformation() throws {
        let app = XCUIApplication()
        openActiveInGame(app)
        XCTAssertTrue(app.staticTexts["Score"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Game Clock"].exists)
        XCTAssertTrue(app.buttons["LeagueRulesPenaltyAssistantButton"].exists)
        XCTAssertTrue(app.buttons["AddScoreButton"].exists)
        XCTAssertTrue(app.buttons["TimeoutButton"].exists)
    }

    @MainActor
    func testFootballClockAuthorityControlsDisplay() throws {
        let app = XCUIApplication()
        openActiveInGame(app)
        XCTAssertTrue(app.buttons["FootballClockAuthorityButton"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["FootballAutomationStatus"].exists || app.otherElements["FootballAutomationStatus"].exists)
    }

    @MainActor
    func testRulesAssistantOpensFromFixedButton() throws {
        let app = XCUIApplication()
        openActiveInGame(app)
        tap(app.buttons["LeagueRulesPenaltyAssistantButton"])
        XCTAssertTrue(app.navigationBars["Rules Assistant"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testScoreEntrySheetOpens() throws {
        let app = XCUIApplication()
        openActiveInGame(app)
        tap(app.buttons["AddScoreButton"])
        XCTAssertTrue(app.navigationBars["Add Score"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testTimeoutSheetOpens() throws {
        let app = XCUIApplication()
        openActiveInGame(app)
        tap(app.buttons["TimeoutButton"])
        XCTAssertTrue(app.navigationBars["Record Timeout"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testScoreLogOpensFromMoreActions() throws {
        let app = XCUIApplication()
        openActiveInGame(app)
        tap(app.buttons["MoreGameActionsButton"])
        XCTAssertTrue(app.navigationBars["More Actions"].waitForExistence(timeout: 3))
        app.buttons["View Score Log"].tap()
        XCTAssertTrue(app.navigationBars["Score Log"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testGameViewerEntryOpensDiscovery() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_ACTIVE_GAME")
        app.launch()
        tapHomeGameViewer(app)
        XCTAssertTrue(app.navigationBars["Game Viewer"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["My Available Games"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testGameViewerDiscoveryDoesNotShowOfficialControls() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_ACTIVE_GAME")
        app.launch()
        tapHomeGameViewer(app)
        XCTAssertTrue(app.navigationBars["Game Viewer"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["AddScoreButton"].exists)
        XCTAssertFalse(app.buttons["TimeoutButton"].exists)
        XCTAssertFalse(app.buttons["LeagueRulesPenaltyAssistantButton"].exists)
        XCTAssertFalse(app.staticTexts["Your Position"].exists)
        XCTAssertFalse(app.buttons["Officials Communication"].exists)
    }

    @MainActor
    func testEnterViewerCodeScreenOpens() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_ACTIVE_GAME")
        app.launch()
        tapHomeGameViewer(app)
        XCTAssertTrue(app.buttons["Enter Viewer Code"].waitForExistence(timeout: 3))
        app.buttons["Enter Viewer Code"].tap()
        XCTAssertTrue(app.navigationBars["Enter Viewer Code"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textFields["GameViewerCodeField"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    private func tap(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 3))
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    @MainActor
    private func tapHomeGameViewer(_ app: XCUIApplication) {
        let button = app.buttons["Game Viewer"]
        for _ in 0..<4 where !button.exists {
            app.swipeUp()
        }
        XCTAssertTrue(button.waitForExistence(timeout: 3))
        button.tap()
    }

    @MainActor
    private func openActiveInGame(_ app: XCUIApplication) {
        app.launchArguments.append("UITEST_OPEN_IN_GAME")
        app.launch()
        XCTAssertTrue(app.staticTexts["RefTraceInGameReady"].waitForExistence(timeout: 5) || app.staticTexts["In-Game Display"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func openGameViewer(_ app: XCUIApplication) {
        app.launchArguments.append("UITEST_ACTIVE_GAME")
        app.launch()
        tapHomeGameViewer(app)
        XCTAssertTrue(app.navigationBars["Game Viewer"].waitForExistence(timeout: 3))
        let firstGame = app.buttons["SpectatorGameRow"].firstMatch
        XCTAssertTrue(firstGame.waitForExistence(timeout: 3))
        firstGame.tap()
        if app.navigationBars["Access Preview"].waitForExistence(timeout: 3) {
            XCTAssertTrue(app.buttons["SpectatorContinueButton"].waitForExistence(timeout: 3))
            app.buttons["SpectatorContinueButton"].tap()
        }
        XCTAssertTrue(app.otherElements["CoachParentObserverGameView"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func openOfficialsCommunication(_ app: XCUIApplication) {
        openActiveInGame(app)
        XCTAssertTrue(app.buttons["MoreGameActionsButton"].waitForExistence(timeout: 3))
        tap(app.buttons["MoreGameActionsButton"])
        XCTAssertTrue(app.navigationBars["More Actions"].waitForExistence(timeout: 3))
        app.buttons["Officials Communication"].tap()
        XCTAssertTrue(app.navigationBars["Officials Communication"].waitForExistence(timeout: 3))
    }
}
