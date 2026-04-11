# SideStack — Flutter Setup Guide
### From Zero to Running on Your Phone

---

## What You're Building

You're converting SideStack from a web app (Vite + React) into a **native Flutter app** that runs on:
- 📱 **iOS** (iPhone)
- 📱 **Android**
- 🖥️ **Desktop** (macOS, Windows, Linux)

Flutter uses a language called **Dart**, which is similar to JavaScript/TypeScript. You'll get comfortable with it quickly.

---

## Part 1: Install Flutter (One-time Setup)

### Step 1 — Install Flutter SDK

**macOS:**
```bash
# Install Homebrew first if you don't have it
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Then install Flutter
brew install --cask flutter
```

**Windows:**
1. Download the Flutter SDK from https://flutter.dev/docs/get-started/install/windows
2. Extract it to `C:\flutter`
3. Add `C:\flutter\bin` to your System PATH

**Linux:**
```bash
sudo snap install flutter --classic
```

### Step 2 — Verify Installation
```bash
flutter doctor
```

This checks your setup and tells you what's missing. You want to see green checkmarks for:
- ✅ Flutter
- ✅ Android toolchain (for Android builds)
- ✅ Xcode (macOS only, for iOS builds)

### Step 3 — Install Android Studio (for Android)
1. Download from https://developer.android.com/studio
2. Open Android Studio → SDK Manager → install Android SDK
3. Run `flutter doctor --android-licenses` and accept all licenses

### Step 4 — Install Xcode (macOS only, for iOS)
1. Install from the Mac App Store (it's free, but ~15GB)
2. Open Terminal and run:
```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

### Step 5 — Install VS Code + Flutter Extension
1. Download VS Code from https://code.visualstudio.com
2. Open VS Code → Extensions (Ctrl+Shift+X)
3. Search "Flutter" and install the official Flutter extension
4. Also install the "Dart" extension

---

## Part 2: Set Up the Project

### Step 1 — Open the Project
1. Unzip the `sidestack_flutter` folder you downloaded
2. Open VS Code
3. File → Open Folder → select `sidestack_flutter`

### Step 2 — Download Fonts
The app uses **Sora** font. Download it:
1. Go to https://fonts.google.com/specimen/Sora
2. Click "Download family"
3. Extract the zip
4. Copy these files into `sidestack_flutter/assets/fonts/`:
   - `Sora-Regular.ttf`
   - `Sora-Medium.ttf`
   - `Sora-SemiBold.ttf`
   - `Sora-Bold.ttf`

> 💡 **Shortcut:** You can also run:
> ```bash
> cd sidestack_flutter
> mkdir -p assets/fonts
> curl -o /tmp/sora.zip "https://fonts.google.com/download?family=Sora"
> unzip /tmp/sora.zip -d /tmp/sora
> cp /tmp/sora/static/*.ttf assets/fonts/
> ```

### Step 3 — Install Dependencies
Open the VS Code terminal (Ctrl+`) and run:
```bash
cd sidestack_flutter
flutter pub get
```

You should see: `Got dependencies!`

---

## Part 3: Run the App

### Option A — Run on a Physical iPhone

1. **Enable Developer Mode on your iPhone:**
   - Settings → Privacy & Security → Developer Mode → On

2. **Connect your iPhone** via USB

3. **Trust the computer** when prompted on your phone

4. **In VS Code:** Press `F5` or click Run → Start Debugging
   - Select your iPhone from the device list

5. **First run only:** You'll need to trust the developer certificate:
   - iPhone Settings → General → VPN & Device Management → your Apple ID → Trust

### Option B — Run on a Physical Android Phone

1. **Enable Developer Options on your Android:**
   - Settings → About Phone → tap "Build Number" 7 times
   - Go back to Settings → Developer Options → Enable USB Debugging

2. **Connect your Android** via USB and tap "Allow" when prompted

3. **In VS Code:** Press `F5`
   - Select your Android device from the list

### Option C — Run on an iOS Simulator (macOS only)

```bash
# Open the iOS Simulator
open -a Simulator

# Then in VS Code, press F5 and select the simulator
```

### Option D — Run on Android Emulator

1. Open Android Studio → Device Manager → Create Device
2. Choose a Pixel phone → Next → select a system image → Finish
3. Click the play button ▶ to start the emulator
4. Back in VS Code, press `F5` and select the emulator

---

## Part 4: Understanding the Project Structure

```
sidestack_flutter/
├── lib/                          ← All your Dart code lives here
│   ├── main.dart                 ← App entry point (like index.js)
│   ├── models/
│   │   └── models.dart           ← Data types: SideStack, Transaction
│   ├── providers/
│   │   └── app_provider.dart     ← State management (like AppContext.tsx)
│   ├── screens/
│   │   ├── main_shell.dart       ← Bottom nav + screen switcher
│   │   ├── dashboard_screen.dart ← Home screen
│   │   ├── stack_detail_screen.dart ← Individual stack view
│   │   ├── analytics_screen.dart ← Charts screen
│   │   └── profile_screen.dart  ← Profile screen
│   ├── widgets/
│   │   ├── shared_widgets.dart   ← Reusable UI components
│   │   ├── add_transaction_sheet.dart ← Quick-add bottom sheet
│   │   └── create_stack_sheet.dart   ← New stack bottom sheet
│   └── theme/
│       └── app_theme.dart        ← Colors, fonts, dark theme
├── assets/
│   └── fonts/                    ← Sora font files go here
├── android/                      ← Android-specific config
├── ios/                          ← iOS-specific config
└── pubspec.yaml                  ← Dependencies (like package.json)
```

### React → Flutter Translation Guide

| React/Web | Flutter/Dart |
|-----------|-------------|
| `useState` | `setState` in `StatefulWidget` |
| `useContext` | `context.watch<AppProvider>()` |
| `div` / `span` | `Container` / `Text` |
| `flexbox` | `Row` / `Column` |
| CSS classes | `TextStyle`, `BoxDecoration` |
| `onClick` | `onTap` / `onPressed` |
| `map()` over array | `ListView.builder` |
| Bottom sheet | `showModalBottomSheet` |
| React Router | Flutter `Navigator` |

---

## Part 5: Connect Firebase (Optional — for real user accounts)

The app currently saves data locally using `shared_preferences`. To add Firebase:

### 1. Create a Firebase Project
1. Go to https://console.firebase.google.com
2. Click "Add project" → name it "SideStack"
3. Disable Google Analytics (not needed yet)

### 2. Install FlutterFire CLI
```bash
dart pub global activate flutterfire_cli
```

### 3. Configure Your App
```bash
cd sidestack_flutter
flutterfire configure
```
Follow the prompts — it auto-generates `firebase_options.dart`.

### 4. Add Firebase packages to pubspec.yaml
```yaml
dependencies:
  firebase_core: ^2.24.2
  firebase_auth: ^4.15.3
  cloud_firestore: ^4.13.6
```

### 5. Update main.dart
```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SideStackApp());
}
```

### 6. Replace SharedPreferences with Firestore
In `app_provider.dart`, replace the `_loadData` / `_save` methods with Firestore calls. The data model is already serializable — just swap `prefs.getString` for `FirebaseFirestore.instance.collection('users').doc(uid)`.

---

## Part 6: Build for Release

### Android APK (share directly)
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle (for Google Play)
```bash
flutter build appbundle --release
```

### iOS (for TestFlight / App Store)
```bash
flutter build ios --release
# Then open ios/Runner.xcworkspace in Xcode and archive
```

---

## Troubleshooting

**`flutter doctor` shows issues with Android licenses:**
```bash
flutter doctor --android-licenses
# Press 'y' to accept each one
```

**`pub get` fails with dependency errors:**
```bash
flutter clean
flutter pub get
```

**App crashes on startup:**
- Check that all font files are in `assets/fonts/`
- Make sure font filenames match exactly what's in `pubspec.yaml`

**"No devices found":**
- Make sure USB debugging is enabled
- Try a different USB cable (some are charge-only)
- Run `flutter devices` to see what's detected

**iOS build fails with "No signing certificate":**
- Open `ios/Runner.xcworkspace` in Xcode
- Go to Signing & Capabilities → select your Apple ID team
- Xcode will auto-provision a development certificate

---

## What's Next

Once the app is running, here are the most impactful next steps:

1. **Add push notifications** — use `flutter_local_notifications` package for daily reminders
2. **Connect Firebase Auth** — add real Google sign-in
3. **Add the 2-stack free limit** — check `provider.stacks.length >= 2` before allowing creation
4. **Submit to App Store / Google Play** — follow the release guide above
5. **Add CSV export** — use the `csv` package to generate downloadable reports

---

*SideStack Flutter — built with ❤️ for hustlers*
