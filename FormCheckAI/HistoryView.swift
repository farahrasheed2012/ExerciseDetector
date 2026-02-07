import SwiftUI

struct HistoryView: View {
    let sessions: [WorkoutSession]
    let onClearHistory: () -> Void

    @Environment(\.dismiss) var dismiss
    @State private var showingClearAlert = false

    var body: some View {
        NavigationView {
            Group {
                if sessions.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No workouts yet")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text("Start a workout to see it here!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(sessions) { session in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(session.date, style: .date)
                                        .font(.headline)
                                    Spacer()
                                    Text(session.date, style: .time)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }

                                HStack {
                                    Label(formatDuration(session.duration), systemImage: "clock")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Label("\(session.totalReps) reps", systemImage: "number")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }

                                HStack(spacing: 12) {
                                    ForEach(session.exercises, id: \.type) { exercise in
                                        HStack(spacing: 4) {
                                            Image(systemName: exercise.type.icon)
                                                .font(.caption)
                                            Text("\(exercise.count)")
                                                .font(.caption.bold())
                                                .monospacedDigit()
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(exercise.type.color)
                                        .cornerRadius(8)
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
            .navigationTitle("Workout History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !sessions.isEmpty {
                        Button(role: .destructive) {
                            showingClearAlert = true
                        } label: {
                            Text("Clear All")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Clear History?", isPresented: $showingClearAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) { onClearHistory() }
            } message: {
                Text("This will permanently delete all workout history.")
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%dm %ds", minutes, seconds)
    }
}
