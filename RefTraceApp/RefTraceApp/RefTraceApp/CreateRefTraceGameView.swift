import SwiftUI

struct CreateRefTraceGameView: View {
    @EnvironmentObject private var router: RefTraceAppRouter
    @EnvironmentObject private var store: RefTraceGameStore
    @State private var draft = CreateRefTraceGameDraft()
    @State private var showingReview = false
    @State private var errors: [RefTraceUserFacingError] = []

    var body: some View {
        Form {
            Section("Game Type") {
                Picker("Sport", selection: $draft.sport) {
                    ForEach(RefTraceSport.allCases) { sport in
                        Text(sport.rawValue).tag(sport)
                    }
                }
                .onChange(of: draft.sport) { _, sport in
                    draft.assignedPosition = sport.positions.first ?? ""
                }
                TextField("League", text: $draft.leagueName)
            }
            Section("Teams") {
                TextField("Home team name", text: $draft.homeTeamName)
                TextField("Home team mascot", text: $draft.homeTeamMascot)
                TextField("Away team name", text: $draft.awayTeamName)
                TextField("Away team mascot", text: $draft.awayTeamMascot)
            }
            Section("Site") {
                TextField("Game-site name", text: $draft.gameSiteName)
                TextField("Game-site address", text: $draft.gameSiteAddress)
                TextField("Field or court", text: $draft.fieldOrCourt)
            }
            Section("Schedule") {
                DatePicker("Game date", selection: $draft.gameDate, displayedComponents: .date)
                DatePicker("Scheduled start", selection: $draft.scheduledStartTime, displayedComponents: [.date, .hourAndMinute])
                    .onChange(of: draft.scheduledStartTime) { _, _ in draft.updateDefaultReportTime() }
                DatePicker("Report time", selection: $draft.reportTime, displayedComponents: [.date, .hourAndMinute])
                if draft.reportTimeDiffersFromDefault {
                    Label("Report time differs from the default 45-minute arrival window.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(RefTraceTheme.warning)
                }
            }
            Section("Officials") {
                Picker("Assigned position", selection: $draft.assignedPosition) {
                    ForEach(draft.sport.positions, id: \.self) { position in
                        Text(position).tag(position)
                    }
                }
                TextField("Other officials", text: $draft.otherOfficials, prompt: Text("Names separated by commas"))
            }
            Section("Notes") {
                TextEditor(text: $draft.notes)
                    .frame(minHeight: 90)
            }
            if !errors.isEmpty {
                Section("Needs Attention") {
                    ForEach(errors.map { $0.localizedDescription }, id: \.self) { message in
                        Text(message)
                            .foregroundStyle(RefTraceTheme.warning)
                    }
                }
            }
        }
        .navigationTitle("Create New Game")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Review") {
                    errors = store.validate(draft)
                    showingReview = errors.isEmpty
                }
            }
        }
        .navigationDestination(isPresented: $showingReview) {
            CreateRefTraceGameReviewView(draft: $draft)
        }
    }
}

struct CreateRefTraceGameReviewView: View {
    @EnvironmentObject private var router: RefTraceAppRouter
    @EnvironmentObject private var store: RefTraceGameStore
    @Environment(\.dismiss) private var dismiss
    @Binding var draft: CreateRefTraceGameDraft
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Review") {
                row("Sport", draft.sport.rawValue)
                row("League", draft.leagueName)
                row("Teams", "\(draft.awayTeamName) \(draft.awayTeamMascot) at \(draft.homeTeamName) \(draft.homeTeamMascot)")
                row("Site", draft.gameSiteName)
                row("Address", draft.gameSiteAddress)
                row("Field or Court", draft.fieldOrCourt)
                row("Start", draft.scheduledStartTime.formatted(date: .abbreviated, time: .shortened))
                row("Report", draft.reportTime.formatted(date: .abbreviated, time: .shortened))
                row("Position", draft.assignedPosition)
                row("Other Officials", draft.otherOfficials.isEmpty ? "None" : draft.otherOfficials)
                row("Notes", draft.notes.isEmpty ? "None" : draft.notes)
            }
            if let errorMessage {
                Section("Unable to Create") {
                    Text(errorMessage)
                        .foregroundStyle(RefTraceTheme.warning)
                }
            }
            Section {
                Button("Save Draft") {
                    do {
                        try store.saveDraft(draft)
                        router.go(.home)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                Button("Create Game") {
                    create(openManagement: false)
                }
                Button("Create and Open Game Management") {
                    create(openManagement: true)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Review Game")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { dismiss() }
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        LabeledContent(title, value: value)
    }

    private func create(openManagement: Bool) {
        do {
            let game = try store.createGame(from: draft, openManagement: openManagement)
            router.go(openManagement ? .gameManagement(game.id) : .home)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
