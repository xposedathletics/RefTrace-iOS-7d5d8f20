import Foundation
import Combine

// ── Penalty ───────────────────────────────────────────────────
struct PenaltyDef: Identifiable {
    let id = UUID()
    let code: String
    let label: String
    let sides: [String]
    let yardage: Int
}

let PENALTIES: [PenaltyDef] = [
    PenaltyDef(code:"HOL", label:"Holding",           sides:["Offense","Defense"], yardage:10),
    PenaltyDef(code:"OFS", label:"Offside",           sides:["Offense"],           yardage:5),
    PenaltyDef(code:"ENC", label:"Encroach",          sides:["Defense"],           yardage:5),
    PenaltyDef(code:"P/I", label:"Pass Interference", sides:["Offense","Defense"], yardage:0),
    PenaltyDef(code:"PF",  label:"Personal Foul",     sides:[],                    yardage:15),
    PenaltyDef(code:"UNS", label:"Unsportsmanlike",   sides:[],                    yardage:15),
]

// ── Score Event ───────────────────────────────────────────────
struct ScoreEvent: Identifiable, Codable {
    var id = UUID()
    let side: String
    let type: String
    let pts: Int
    let periodLabel: String
    let clock: String
    let wall: String
    let ts: Date
}

// ── Flag Event ────────────────────────────────────────────────
struct FlagEvent: Identifiable, Codable {
    var id = UUID()
    let code: String
    let label: String
    let side: String
    let team: String
    let teamName: String
    let mascot: String
    let playerNum: String
    let periodLabel: String
    let clock: String
    let wall: String
    let ts: Date
}

// ── Game Period ───────────────────────────────────────────────
struct GamePeriod: Identifiable, Codable {
    var id = UUID()
    let label: String
    let maxSecs: Int
    var scores: [ScoreEvent] = []
}

// ── Crew Message ──────────────────────────────────────────────
struct CrewMessage: Identifiable, Codable {
    var id = UUID()
    let sender: String
    let senderName: String
    let senderRole: String
    let text: String
    let type: String
    let directTo: String
    let isHeadRef: Bool
    let ts: Date
}

// ── Main Game State ───────────────────────────────────────────
class GameState: ObservableObject {
    @Published var sport:        String = "Football"
    @Published var position:     String = "Head Referee"
    @Published var firstName:    String = ""
    @Published var lastName:     String = ""
    @Published var homeTeam:     String = ""
    @Published var awayTeam:     String = ""
    @Published var homeMascot:   String = ""
    @Published var awayMascot:   String = ""
    @Published var notifyPhones: String = ""
    @Published var sessionCode:  String = String(format:"%04d", Int.random(in:1000...9999))
    @Published var gameStarted:  Bool   = false
    @Published var gameLogId:    String = ""

    @Published var clock:   Int  = 48 * 60
    @Published var running: Bool = false

    @Published var periods:   [GamePeriod] = []
    @Published var periodIdx: Int = 0
    @Published var otCount:   Int = 0

    @Published var homeScore: Int = 0
    @Published var awayScore: Int = 0
    @Published var homeTO:    Int = 3
    @Published var awayTO:    Int = 3
    @Published var scoreLog:  [ScoreEvent] = []
    @Published var flags:     [FlagEvent]  = []

    @Published var crewMessages: [CrewMessage] = []

    var isHeadRef: Bool     { position == "Head Referee" }
    var periodLabel: String { periods.indices.contains(periodIdx) ? periods[periodIdx].label : "Q1" }
    var home: String        { homeTeam.isEmpty ? "Home" : homeTeam }
    var away: String        { awayTeam.isEmpty ? "Away" : awayTeam }

    func incrementHome() {
        homeScore += 1
    }

    func decrementHome() {
        homeScore = max(0, homeScore - 1)
    }

    func incrementAway() {
        awayScore += 1
    }

    func decrementAway() {
        awayScore = max(0, awayScore - 1)
    }


    // MARK: - Reset periods for selected sport
    func resetForSport() {
        let count  = sport == "Football" ? 4 : 2
        let prefix = sport == "Football" ? "Q" : "H"
        let secs   = sport == "Football" ? 48 * 60 : 20 * 60
        periods   = (1...count).map { GamePeriod(label: "\(prefix)\($0)", maxSecs: secs) }
        periodIdx = 0
        clock     = secs
        otCount   = 0
    }

    // MARK: - Add overtime period
    func addOT() {
        otCount += 1
        let newPeriod = GamePeriod(label: "OT\(otCount)", maxSecs: 10 * 60)
        periods.append(newPeriod)
        periodIdx = periods.count - 1
        clock     = 10 * 60
        running   = false
    }
}
