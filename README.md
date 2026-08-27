<<<<<<< HEAD
# 📋 Attendance App

A simple Flutter attendance management app with **Admin** and **Teacher** roles.

---

## 🧭 App Overview

| Role | What they do |
|------|-------------|
| **Admin** | Add teachers, create courses, enroll students |
| **Teacher** | Log in, view assigned courses, take attendance |

### Default Login Credentials

| Role | Username | Password |
|------|----------|----------|
| Admin | `admin` | `123` |
| Teacher | *(set by admin)* | *(set by admin)* |

---

## ⚙️ Prerequisites — Install These First

### 1. Install Flutter SDK
1. Go to 👉 https://docs.flutter.dev/get-started/install/windows
2. Download the Flutter SDK zip and extract it (e.g., to `C:\flutter`)
3. Add `C:\flutter\bin` to your **System PATH**
4. Open a new terminal and verify:
   ```
   flutter --version
   ```

### 2. Install Visual Studio Code
1. Download from 👉 https://code.visualstudio.com/
2. Install these VS Code extensions:
   - **Flutter** (by Dart Code)
   - **Dart** (by Dart Code)

### 3. Install Google Chrome
- Download from 👉 https://www.google.com/chrome/

### 4. Install Android Studio (for Android)
1. Download from 👉 https://developer.android.com/studio
2. During install, make sure **Android SDK** is included
3. Open Android Studio → **Virtual Device Manager** → Create an emulator (e.g., Pixel 6, API 33)
4. OR connect a real Android phone via USB with **USB Debugging** enabled

---

## 📥 How to Clone and Run the App

### Step 1 — Clone the Repository
Open a terminal (CMD or PowerShell) and run:

```bash
git clone https://github.com/Akash235711/atendance-app.git
cd atendance-app
```

### Step 2 — Open in VS Code
```bash
code .
```

### Step 3 — Get Dependencies
In the VS Code terminal (`Ctrl + `` ` ``):
```bash
flutter pub get
```

---

## 🌐 Run on Chrome (Web)

```bash
flutter run -d chrome
```

The app will open automatically in Google Chrome.

> **Hot Reload:** While the app is running, press `r` in the terminal to reload after code changes.

---

## 📱 Run on Android

### Option A — Android Emulator (Virtual Device)

1. Open **Android Studio**
2. Go to **Device Manager** → Start your emulator
3. Wait for the emulator to fully boot
4. Then run:
   ```bash
   flutter run -d android
   ```

### Option B — Real Android Phone (USB)

1. On your phone: **Settings → Developer Options → Enable USB Debugging**
2. Connect phone to PC via USB
3. Accept the "Allow USB Debugging" prompt on your phone
4. Run:
   ```bash
   flutter devices
   ```
   Your phone should appear in the list.
5. Then run:
   ```bash
   flutter run
   ```

---

## 🛠️ Run from VS Code (Easier Way)

1. Open VS Code with the project
2. Press `F5` OR click **Run → Start Debugging**
3. VS Code will show a device picker at the top — select **Chrome** or your **Android device**
4. The app will build and launch automatically

---

## 📖 How to Use the App

### Admin Setup (do this first)

1. Open the app → tap **Admin Login** → enter password `123`
2. Go to **Teachers** tab → tap **Add Teacher**
   - Enter teacher name, username, and password
3. Go to **Courses** tab → tap **Add Course**
   - Enter course name and assign to a teacher
4. Go to **Students** tab → tap **Enroll Student**
   - Enter student name, roll number, and select a course
5. Log out

### Teacher — Taking Attendance

1. Tap **Teacher Login** → enter username and password (set by admin)
2. **My Courses** tab shows all courses assigned to you
3. Tap **Take Attendance** on a course
4. Select the date (tap the date bar at top)
5. Mark each student:
   - **P** = Present (green)
   - **A** = Absent (red)
   - **L** = Late (orange)
   - Or use **Mark All** bar at the bottom
6. Go to **Records** tab to view all past attendance

---

## 📁 Project Structure

```
lib/
└── main.dart       # Entire app in one file
pubspec.yaml        # Dependencies
```

## 📦 Dependencies

| Package | Purpose |
|---------|---------|
| `flutter` | UI framework |
| `shared_preferences` | Local data storage |
| `cupertino_icons` | Icons |

---

## 🔧 Useful Flutter Commands

| Command | What it does |
|---------|-------------|
| `flutter pub get` | Install dependencies |
| `flutter run -d chrome` | Run on Chrome |
| `flutter run -d android` | Run on Android |
| `flutter devices` | List connected devices |
| `flutter doctor` | Check setup issues |
| `flutter build apk` | Build Android APK |

---

## 🩺 Troubleshooting

**`flutter: command not found`**
→ Flutter is not in your PATH. Re-add `C:\flutter\bin` to System PATH and restart terminal.

**`No supported devices connected`**
→ Run `flutter devices` to see what's available. Use `-d chrome` or `-d android` explicitly.

**Web not supported error**
→ Run `flutter create .` inside the project folder to add web support, then try again.

**Android emulator not showing**
→ Make sure the emulator is fully booted in Android Studio before running `flutter run`.
=======
# atendance-app
>>>>>>> a4ddf4df41850f9479240925d55e3799604ec8b5
