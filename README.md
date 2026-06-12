# PosturePro — AI Gym Posture Coach

Real-time posture detection for **10 gym exercises** using Google ML Kit Pose Detection on Android.

---

## Features

| Feature | Details |
|---|---|
| 🎯 Exercises | Squat, Push-up, Lunge, Plank, Deadlift, Bicep Curl, Shoulder Press, Sit-up, Burpee, Jumping Jack |
| 🦴 Skeleton Overlay | Live colour-coded skeleton (green=good, yellow=warning, red=bad) |
| 📐 Joint Angles | Real-time angle measurement for each key joint |
| 🔢 Rep Counter | Automatic rep counting via pose phase detection |
| 💯 Form Score | Percentage score based on how many joints are in correct range |
| 📋 Feedback | Instant specific feedback on what to fix |

---

## Prerequisites

- Flutter SDK ≥ 3.0.0
- Android Studio / VS Code
- Android device or emulator with **API 21+** (physical device strongly recommended for ML Kit)
- Enable **Developer Options → USB Debugging** on your Android phone

---

## Setup Steps

### 1. Get the project
```bash
cd posture_detection
flutter pub get
```

### 2. Add missing Android files

Create `android/app/src/main/kotlin/com/example/posture_detection/MainActivity.kt`:
```kotlin
package com.example.posture_detection

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity()
```

Create `android/build.gradle`:
```groovy
buildscript {
    ext.kotlin_version = '1.9.0'
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath 'com.android.tools.build:gradle:8.1.0'
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.buildDir = '../build'
subprojects {
    project.buildDir = "${rootProject.buildDir}/${project.name}"
}
subprojects {
    project.evaluationDependsOn(':app')
}

tasks.register("clean", Delete) {
    delete rootProject.buildDir
}
```

Create `android/settings.gradle`:
```groovy
include ':app'

def localPropertiesFile = new File(rootProject.projectDir, "local.properties")
def properties = new Properties()
assert localPropertiesFile.exists()
localPropertiesFile.withReader("UTF-8") { reader -> properties.load(reader) }

def flutterSdkPath = properties.getProperty("flutter.sdk")
assert flutterSdkPath != null, "flutter.sdk not set in local.properties"
apply from: "$flutterSdkPath/packages/flutter_tools/gradle/app_plugin_loader.gradle"
```

Create `android/gradle/wrapper/gradle-wrapper.properties`:
```
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.3-all.zip
```

### 3. Grant camera permission
The app will request camera permission on first launch. Grant it.

### 4. Run
```bash
flutter run
```

---

## How It Works

### Pose Detection Pipeline
```
Camera Frame → CameraImage → InputImage → ML Kit PoseDetector
    → Pose (33 landmarks with x,y,z + likelihood)
    → PostureAnalyzer.analyze(pose, exerciseId)
    → Joint angle calculations
    → Compare against exercise-specific valid ranges
    → PostureResult (status, score, feedback, rep count)
    → UI update
```

### Exercise-Specific Rules

Each exercise checks 3 key joint angles:

| Exercise | Joints Checked | Rep Trigger |
|---|---|---|
| Squat | Knee angle (70-110°), Hip angle | Knee < 110° = down |
| Push-up | Elbow angle (80-175°), Body line (160-185°) | Elbow < 120° = down |
| Lunge | Front knee (80-100°), Back knee, Torso | Front knee < 100° = down |
| Plank | Body alignment (165-185°), Shoulder stack | N/A (hold) |
| Deadlift | Hip hinge (60-150°), Knee bend, Spine | Hip < 100° = down |
| Bicep Curl | Elbow (30-170°), Elbow position | Elbow > 140° = down |
| Shoulder Press | Arm raise (160-185°), Elbow start | Arm < 100° = down |
| Sit-up | Torso rise (60-130°), Knee bend, Neck | Torso > 110° = down |
| Burpee | Body plank (160-185°), Arms, Hip | Plank + elbow < 120° = down |
| Jumping Jack | Arm raise (150-185°), Leg spread | Arms down = down |

### Posture Status Colors
- 🟢 **Green** — All joints in correct range
- 🟡 **Yellow** — 1+ joints slightly out of range (±15% tolerance)
- 🔴 **Red** — 1+ joints clearly out of range
- ⚫ **Grey** — Pose not detected

---

## Customisation

### Adjust angle ranges
Open `lib/models/exercise.dart` and modify `minAngle`/`maxAngle` in each `_analyze*` method.

### Add a new exercise
1. Add to `kExercises` list in `exercise.dart`
2. Add a `_analyzeMyExercise(Pose pose)` method in `PostureAnalyzer`
3. Add a case in the `analyze()` switch statement

---

## Troubleshooting

**"No pose detected"** — Ensure full body is visible, good lighting, stand 1.5-2m from camera.

**Slow detection** — Use `PoseDetectionModel.base` instead of `accurate` in `camera_service.dart` for faster (less accurate) results.

**Build fails** — Run `flutter clean && flutter pub get` then rebuild.

**Camera permission denied** — Go to Android Settings → Apps → PosturePro → Permissions → Camera → Allow.
