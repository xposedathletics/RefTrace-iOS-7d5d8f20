import SwiftUI

struct OfficialEaseGameImportView: View {
    @EnvironmentObject private var router: RefTraceAppRouter
    @EnvironmentObject private var store: RefTraceGameStore
    @State private var searchText = ""
    @State private var selectedSport: RefTraceSport?
    @State private var selectedStatus = "All"
    @State private var transferCode = ""
    @State private var errorMessage: String?

    private let statuses = ["All", "Assigned", "Accepted", "Ready"]

    private var filteredAssignments: [OfficialEaseAssignment] {
        store.pendingAssignments.filter { assignment in
            let searchMatches = searchText.isEmpty || assignment.game.teamsDisplayName.localizedCaseInsensitiveContains(searchText) || assignment.game.leagueName.localizedCaseInsensitiveContains(searchText)
            let sportMatches = selectedSport == nil || assignment.game.sport == selectedSport
            let statusMatches = selectedStatus == "All" || assignment.status == selectedStatus
            return searchMatches && sportMatches && statusMatches
        }
    }

    var body: some View {
        List {
            Section("Connection") {
                Label(store.syncSummary.connectionStatus.rawValue, systemImage: connectionSymbol)
                if store.syncSummary.connectionStatus == .offline {
                    Text("RefTrace is offline. Saved games remain available, but OfficialEase imports and synchronization require a connection.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Button("Refresh from OfficialEase") { store.refreshOfficialEaseAssignments() }
            }
            Section("Enter Transfer Code") {
                SecureField("Transfer ID or one-time transfer code", text: $transferCode)
                    .textInputAutocapitalization(.characters)
                Button("Validate Code") { validateCode() }
            }
            Section("Pending OfficialEase Assignments") {
                TextField("Search by team or league", text: $searchText)
                Picker("Sport", selection: $selectedSport) {
                    Text("All").tag(nil as RefTraceSport?)
                    ForEach(RefTraceSport.allCases) { sport in
                        Text(sport.rawValue).tag(sport as RefTraceSport?)
                    }
                }
                Picker("Status", selection: $selectedStatus) {
                    ForEach(statuses, id: \.self) { status in Text(status).tag(status) }
                }
                if filteredAssignments.isEmpty {
                    Text("No OfficialEase assignments are currently available.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredAssignments) { assignment in
                        OfficialEaseAssignmentCard(assignment: assignment)
                    }
                }
            }
            Section("Open Received Deep Link") {
                Text("Received links open directly to import preview when they use reftrace://game/start?transferID=<transfer-id> or the configured Universal Link route.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let errorMessage {
                Section("Error") {
                    Text(errorMessage)
                        .foregroundStyle(RefTraceTheme.warning)
                }
            }
        }
        .navigationTitle("Pull from OfficialEase")
    }

    private var connectionSymbol: String {
        switch store.syncSummary.connectionStatus {
        case .upToDate: return "checkmark.circle.fill"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .pending: return "clock.fill"
        case .offline: return "wifi.slash"
        case .failed: return "exclamationmark.triangle.fill"
        case .authenticationRequired: return "person.crop.circle.badge.exclamationmark"
        }
    }

    private func validateCode() {
        switch store.validateTransferCode(transferCode) {
        case .success(let assignment):
            router.go(.importPreview(assignment.transferID))
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}

private struct OfficialEaseAssignmentCard: View {
    @EnvironmentObject private var router: RefTraceAppRouter
    @EnvironmentObject private var store: RefTraceGameStore
    let assignment: OfficialEaseAssignment
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(assignment.game.teamsDisplayName)
                .font(.headline)
            Text("\(assignment.game.sport.rawValue) • \(assignment.game.leagueName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(assignment.game.scheduledStartTime.formatted(date: .abbreviated, time: .shortened)) • Report \(assignment.game.reportTime.formatted(date: .omitted, time: .shortened))")
                .font(.subheadline)
            Text("\(assignment.game.gameSiteName) • \(assignment.game.fieldOrCourt)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Position: \(assignment.game.assignedPosition) • Status: \(assignment.status)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Expires: \(assignment.expiresAt?.formatted(date: .abbreviated, time: .shortened) ?? "Not listed")")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Preview") { router.go(.importPreview(assignment.transferID)) }
                Button("Import") { importGame(open: false) }
                Button("Refresh") { store.refreshOfficialEaseAssignments() }
            }
            .buttonStyle(.bordered)
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(RefTraceTheme.warning)
            }
        }
        .padding(.vertical, 6)
    }

    private func importGame(open: Bool) {
        do {
            let game = try store.importAssignment(assignment, openManagement: open)
            router.go(open ? .gameManagement(game.id) : .home)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
