import SwiftUI

struct OfficialEaseGameImportPreviewView: View {
    @EnvironmentObject private var router: RefTraceAppRouter
    @EnvironmentObject private var store: RefTraceGameStore
    let transferID: String
    @State private var errorMessage: String?

    private var assignment: OfficialEaseAssignment? {
        store.assignment(for: transferID)
    }

    var body: some View {
        Group {
            if let assignment {
                List {
                    Section("Game") {
                        row("Sport", assignment.game.sport.rawValue)
                        row("League", assignment.game.leagueName)
                        row("Teams", assignment.game.teamsDisplayName)
                        row("Game Date", assignment.game.gameDate.formatted(date: .abbreviated, time: .omitted))
                        row("Scheduled Time", assignment.game.scheduledStartTime.formatted(date: .abbreviated, time: .shortened))
                        row("Report Time", assignment.game.reportTime.formatted(date: .abbreviated, time: .shortened))
                        row("Site", assignment.game.gameSiteName)
                        row("Field or Court", assignment.game.fieldOrCourt)
                    }
                    Section("Assignment") {
                        row("Assigned Official", assignment.assignedOfficialName)
                        row("Assigned Position", assignment.game.assignedPosition)
                        row("Transfer ID", assignment.transferID)
                        row("OfficialEase Assignment ID", assignment.assignmentID)
                        row("Rule Version", assignment.game.ruleVersion ?? "Unavailable")
                        row("Transfer Expiration", assignment.expiresAt?.formatted(date: .abbreviated, time: .shortened) ?? "Unavailable")
                        row("Data Validation", validationText(for: assignment))
                    }
                    if assignment.game.ruleVersion == nil {
                        Section("Rules") {
                            Text("No rules have been synchronized for this league and sport.")
                                .foregroundStyle(RefTraceTheme.warning)
                        }
                    }
                    if let errorMessage {
                        Section("Unable to Import") {
                            Text(errorMessage)
                                .foregroundStyle(RefTraceTheme.warning)
                        }
                    }
                    Section {
                        Button("Cancel") { router.go(.home) }
                        Button("Import Game") { importGame(open: false) }
                        Button("Import and Open") { importGame(open: true) }
                            .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                ContentUnavailableView("Transfer Not Found", systemImage: "exclamationmark.triangle", description: Text("This transfer code is invalid or no longer available."))
            }
        }
        .navigationTitle("Import Preview")
    }

    private func row(_ title: String, _ value: String) -> some View {
        LabeledContent(title, value: value)
    }

    private func validationText(for assignment: OfficialEaseAssignment) -> String {
        store.validateTransfer(assignment)?.localizedDescription ?? "Ready to import"
    }

    private func importGame(open: Bool) {
        guard let assignment else {
            errorMessage = RefTraceUserFacingError.transferInvalid.localizedDescription
            return
        }
        do {
            let game = try store.importAssignment(assignment, openManagement: open)
            router.go(open ? .gameManagement(game.id) : .home)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
