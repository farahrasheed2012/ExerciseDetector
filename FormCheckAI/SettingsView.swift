import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("confidenceThreshold") private var confidenceThreshold: Double = 0.7
    @AppStorage("hapticEnabled") private var hapticEnabled: Bool = true

    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Confidence Threshold")
                            Spacer()
                            Text("\(Int(confidenceThreshold * 100))%")
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $confidenceThreshold, in: 0.5...0.9, step: 0.05)
                        Text("Higher values require more certainty before counting reps")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Detection Settings")
                }

                Section {
                    Toggle("Haptic Feedback on Reps", isOn: $hapticEnabled)
                    Text("Vibrate when a rep is detected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Feedback")
                }

                Section {
                    HStack {
                        Text("Model Type")
                        Spacer()
                        Text("EdgeImpulse C++")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Input Size")
                        Spacer()
                        Text("220 x 220")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Exercises")
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Arm Raise")
                            Text("Standing")
                            Text("Lunge")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }

                Section {
                    Link(destination: URL(string: "https://edgeimpulse.com")!) {
                        HStack {
                            Text("EdgeImpulse")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Links")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
