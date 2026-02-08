import SwiftUI

enum ExerciseType: String, CaseIterable, Codable {
    case armRaise = "Arm Raise"
    case standing = "Standing"
    case lunge = "Lunge"
    case unknown = "Unknown"

    /// Map Edge Impulse model output labels to ExerciseType (e.g. "arm_raise" -> .armRaise).
    static func fromModelLabel(_ label: String) -> ExerciseType? {
        switch label.lowercased() {
        case "arm_raise": return .armRaise
        case "lunge": return .lunge
        case "standing": return .standing
        default: return nil
        }
    }

    var color: Color {
        switch self {
        case .armRaise: return .blue
        case .standing: return .green
        case .lunge: return .orange
        case .unknown: return .gray
        }
    }

    var icon: String {
        switch self {
        case .armRaise: return "figure.arms.open"
        case .standing: return "figure.stand"
        case .lunge: return "figure.walk"
        case .unknown: return "questionmark"
        }
    }
}

struct WorkoutSession: Identifiable, Codable {
    let id: UUID
    let date: Date
    let duration: TimeInterval
    var exercises: [ExerciseCount]

    init(id: UUID = UUID(), date: Date, duration: TimeInterval, exercises: [ExerciseCount]) {
        self.id = id
        self.date = date
        self.duration = duration
        self.exercises = exercises
    }

    var totalReps: Int {
        exercises.reduce(0) { $0 + $1.count }
    }
}

struct ExerciseCount: Codable {
    let type: ExerciseType
    var count: Int
}
