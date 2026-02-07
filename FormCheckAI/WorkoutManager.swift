import SwiftUI
import Combine

class WorkoutManager: ObservableObject {
    @Published var isActive: Bool = false
    @Published var currentReps: [ExerciseType: Int] = [:]
    @Published var workoutDuration: TimeInterval = 0
    @Published var sessions: [WorkoutSession] = []

    private var startTime: Date?
    private var timer: Timer?

    private var lastStableExercise: ExerciseType = .standing
    private var currentExercise: ExerciseType = .standing
    private var stableFrameCount: Int = 0
    private let STABILITY_THRESHOLD = 10

    @AppStorage("confidenceThreshold") private var confidenceThreshold: Double = 0.7
    @AppStorage("hapticEnabled") private var hapticEnabled: Bool = true

    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    init() {
        loadSessions()
        resetReps()
    }

    private func resetReps() {
        currentReps = [.armRaise: 0, .standing: 0, .lunge: 0]
    }

    func startWorkout() {
        isActive = true
        startTime = Date()
        resetReps()
        workoutDuration = 0
        lastStableExercise = .standing
        currentExercise = .standing
        stableFrameCount = 0

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let start = self?.startTime else { return }
            self?.workoutDuration = Date().timeIntervalSince(start)
        }

        haptic.prepare()
    }

    func stopWorkout() {
        guard isActive else { return }

        isActive = false
        timer?.invalidate()
        timer = nil

        let session = WorkoutSession(
            date: startTime ?? Date(),
            duration: workoutDuration,
            exercises: currentReps.compactMap { type, count in
                count > 0 ? ExerciseCount(type: type, count: count) : nil
            }.sorted { $0.type.rawValue < $1.type.rawValue }
        )

        if session.totalReps > 0 {
            sessions.insert(session, at: 0)
            saveSessions()
        }
    }

    func processDetection(_ exercise: ExerciseType, confidence: Double) {
        guard isActive, confidence >= confidenceThreshold else { return }

        if exercise == currentExercise {
            stableFrameCount += 1
        } else {
            stableFrameCount = 1
            currentExercise = exercise
        }

        if stableFrameCount >= STABILITY_THRESHOLD {
            detectRep(exercise)
        }
    }

    private func detectRep(_ newExercise: ExerciseType) {
        if lastStableExercise == .standing && newExercise != .standing && newExercise != .unknown {
            lastStableExercise = newExercise
        } else if lastStableExercise != .standing && newExercise == .standing {
            currentReps[lastStableExercise, default: 0] += 1
            if hapticEnabled { haptic.impactOccurred() }
            lastStableExercise = .standing
        }
    }

    private func saveSessions() {
        if let encoded = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: "workoutSessions")
        }
    }

    private func loadSessions() {
        if let data = UserDefaults.standard.data(forKey: "workoutSessions"),
           let decoded = try? JSONDecoder().decode([WorkoutSession].self, from: data) {
            sessions = decoded
        }
    }

    func clearHistory() {
        sessions.removeAll()
        saveSessions()
    }
}
