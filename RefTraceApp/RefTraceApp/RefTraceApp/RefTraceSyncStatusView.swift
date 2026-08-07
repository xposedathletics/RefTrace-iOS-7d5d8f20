import SwiftUI

struct RefTraceSyncStatusView: View {
    @EnvironmentObject private var store: RefTraceGameStore

    var body: some View {
        List {
            Section("OfficialEase") {
                LabeledContent("Connection", value: store.syncSummary.connectionStatus.rawValue)
                LabeledContent("Last Sync", value: formatted(store.syncSummary.lastSuccessfulSync))
                LabeledContent("Pending Inbound", value: "\(store.syncSummary.pendingInboundAssignments)")
                LabeledContent("Pending Outbound", value: "\(store.syncSummary.pendingOutboundRecords)")
            }
            Section("Rules and Results") {
                LabeledContent("Rules", value: store.syncSummary.rulesSyncStatus.rawValue)
                LabeledContent("Completion Sync", value: store.syncSummary.gameCompletionSyncStatus.rawValue)
            }
            if let lastSyncError = store.syncSummary.lastSyncError {
                Section("Last Error") {
                    Text(lastSyncError)
                        .foregroundStyle(RefTraceTheme.warning)
                }
            }
            Button {
                store.retrySync()
            } label: {
                Label("Retry Sync", systemImage: "arrow.triangle.2.circlepath")
            }
        }
        .navigationTitle("Sync Status")
    }

    private func formatted(_ date: Date?) -> String {
        guard let date else { return "Never" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
