import SwiftUI

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var workoutManager = WorkoutManager()
    @State private var showingHistory = false
    @State private var showingSettings = false

    var body: some View {
        NavigationView {
            ZStack {
                if cameraManager.cameraPermissionGranted {
                    CameraView(session: cameraManager.getCaptureSession())
                        .ignoresSafeArea()
                } else {
                    Color.black.ignoresSafeArea()
                    VStack(spacing: 20) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                        Text("Camera Access Required")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        Text("Please enable camera access in Settings")
                            .foregroundColor(.white.opacity(0.7))
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                VStack(spacing: 0) {
                    // Top HUD
                    VStack(spacing: 12) {
                        Text(cameraManager.currentExercise.rawValue)
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundColor(cameraManager.currentExercise.color)
                            .shadow(color: .black.opacity(0.7), radius: 4)
                            .animation(.easeInOut(duration: 0.3), value: cameraManager.currentExercise)

                        HStack(spacing: 12) {
                            ProgressView(value: cameraManager.confidence)
                                .tint(cameraManager.confidence > 0.7 ? .green : .orange)
                                .frame(width: 150)
                            Text("\(Int(cameraManager.confidence * 100))%")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                                .monospacedDigit()
                                .shadow(radius: 2)
                        }

                        Text("\(cameraManager.fps) FPS")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .shadow(radius: 2)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.top, 60)

                    Spacer()

                    if workoutManager.isActive {
                        VStack(spacing: 16) {
                            Text(formatDuration(workoutManager.workoutDuration))
                                .font(.system(size: 40, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .shadow(radius: 4)

                            HStack(spacing: 20) {
                                RepCounter(exercise: .armRaise, count: workoutManager.currentReps[.armRaise] ?? 0)
                                RepCounter(exercise: .lunge, count: workoutManager.currentReps[.lunge] ?? 0)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal)
                        .transition(.scale.combined(with: .opacity))
                    }

                    Spacer()

                    Button(action: {
                        withAnimation {
                            if workoutManager.isActive {
                                workoutManager.stopWorkout()
                            } else {
                                workoutManager.startWorkout()
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: workoutManager.isActive ? "stop.fill" : "play.fill")
                            Text(workoutManager.isActive ? "Stop Workout" : "Start Workout")
                        }
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: 280)
                        .padding(.vertical, 20)
                        .background(workoutManager.isActive ? Color.red : Color.green)
                        .cornerRadius(30)
                        .shadow(radius: 10)
                    }
                    .padding(.bottom, 50)
                }
            }
            .onAppear {
                if cameraManager.cameraPermissionGranted {
                    cameraManager.setupCamera()
                    cameraManager.start()
                }
            }
            .onDisappear {
                cameraManager.stop()
            }
            .onChange(of: cameraManager.currentExercise) { exercise in
                workoutManager.processDetection(exercise, confidence: cameraManager.confidence)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
            }
            .sheet(isPresented: $showingHistory) {
                HistoryView(sessions: workoutManager.sessions, onClearHistory: {
                    workoutManager.clearHistory()
                })
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct RepCounter: View {
    let exercise: ExerciseType
    let count: Int

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: exercise.icon)
                .font(.title2)
                .foregroundColor(.white)
            Text(exercise.rawValue)
                .font(.subheadline.bold())
                .foregroundColor(.white)
            Text("\(count)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundColor(exercise.color)
                .monospacedDigit()
        }
        .frame(width: 140, height: 120)
        .background(Color.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
    }
}
