# EdgeImpulse C++ Library Integration Steps

## Overview
This app uses an EdgeImpulse C++ vision model located at:
`/Users/farah/Documents/FarahRasheed/ExerciseDetector`

The model detects three exercise classes: **Arm Raise**, **Standing**, and **Lunge**.

- **Input size:** 220 x 220 pixels (RGB)
- **Output:** 3 classification labels with confidence scores
- **Inference type:** TFLite (compiled, float32)

---

## Current State

The app ships with a **mock implementation** in `EdgeImpulseWrapper.mm` that cycles through exercises so you can test the UI immediately without the EdgeImpulse library linked. Follow the steps below to integrate the real model.

---

## Integration Steps

### 1. Add EdgeImpulse Library to Xcode Project

1. Open `FormCheckAI.xcodeproj` in Xcode
2. Open Finder and navigate to: `/Users/farah/Documents/FarahRasheed/ExerciseDetector`
3. Drag these **3 folders** into your Xcode project navigator (into the `FormCheckAI` group):
   - `edge-impulse-sdk/`
   - `model-parameters/`
   - `tflite-model/`
4. When Xcode prompts:
   - Select **"Create groups"** (NOT "Create folder references")
   - Check **"Add to targets: FormCheckAI"**
   - Check **"Copy items if needed"**

### 2. Configure Build Settings

Click on your **project** (FormCheckAI) in the navigator, select the **FormCheckAI target**, go to **Build Settings**:

| Setting | Value |
|---------|-------|
| **Header Search Paths** | `$(SRCROOT)/FormCheckAI/edge-impulse-sdk` (Recursive) |
| **C++ Language Dialect** | `GNU++14` or `C++14` |
| **C++ Standard Library** | `libc++` (already set) |
| **Enable Bitcode** | `No` (already set) |
| **Other Linker Flags** | `-lc++` (already set) |
| **Objective-C Bridging Header** | `FormCheckAI/FormCheckAI-Bridging-Header.h` (already set) |

### 3. Update EdgeImpulseWrapper.mm

1. **Uncomment** the import statements at the top:
   ```objc
   #import "edge-impulse-sdk/classifier/ei_run_classifier.h"
   #import "edge-impulse-sdk/dsp/image/image.hpp"
   #import "model-parameters/model_metadata.h"
   ```

2. Update `getInputWidth` and `getInputHeight` to use the real constants:
   ```objc
   - (int)getInputWidth {
       return EI_CLASSIFIER_INPUT_WIDTH;
   }
   - (int)getInputHeight {
       return EI_CLASSIFIER_INPUT_HEIGHT;
   }
   ```

3. **Delete** the entire mock implementation section (the block that returns fake predictions)

4. **Uncomment** the real implementation section (everything inside the `/* ... */` block)

### 4. Verify Compilation

1. Go to **Build Phases** > **Compile Sources**
2. Ensure `EdgeImpulseWrapper.mm` is listed
3. Clean build folder: **Product > Clean Build Folder** (Cmd+Shift+K)
4. Build: **Product > Build** (Cmd+B)

### 5. Test on Real Device

**Important:** This app requires a real iPhone -- the simulator does not have a camera.

1. Connect your iPhone via USB
2. Select your iPhone as the run destination
3. Set your development team under **Signing & Capabilities**
4. **Product > Run** (Cmd+R)
5. Grant camera permission when prompted

---

## Troubleshooting

### Build Errors
- Verify all 3 folders (`edge-impulse-sdk`, `model-parameters`, `tflite-model`) are in your project
- Check Header Search Paths are set correctly and marked as Recursive
- Ensure C++ Language Dialect is C++14 or higher
- Clean and rebuild (Cmd+Shift+K, then Cmd+B)

### Runtime Errors
- Check Console logs for "Classification failed" messages
- Verify the model input size matches (220x220)
- Check that pixel normalization is correct (0-1 range for float32 models)

### Low Accuracy
- Adjust confidence threshold in the app's Settings screen
- Ensure good lighting conditions
- Stand at an appropriate distance from the camera
- Verify model input dimensions are correct

---

## App Architecture

| File | Purpose |
|------|---------|
| `FormCheckAIApp.swift` | App entry point |
| `ContentView.swift` | Main UI with camera overlay |
| `CameraView.swift` | Camera preview (UIViewRepresentable) |
| `CameraManager.swift` | AVFoundation capture + frame processing |
| `WorkoutManager.swift` | Rep counting state machine + session history |
| `ExerciseType.swift` | Data models (ExerciseType, WorkoutSession) |
| `HistoryView.swift` | Past workout sessions |
| `SettingsView.swift` | Confidence threshold, haptics |
| `EdgeImpulseWrapper.h/.mm` | Objective-C++ bridge to EdgeImpulse C++ SDK |
| `FormCheckAI-Bridging-Header.h` | Swift to Obj-C bridge |

---

## Performance Notes

- The app targets ~30 FPS camera capture
- Frame processing skips frames if the previous one is still being classified
- The FPS counter in the UI shows actual processed frame rate
- On modern iPhones, inference should be well under 100ms per frame
