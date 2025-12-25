# GreensWrld Frontend: Authentication & UI Updates

This document summarizes all changes made to the frontend so the team can integrate and use the new features.

---

## 1. Firebase Setup

- Connected the Flutter app to **Firebase** using `flutterfire configure`.
- Configured primarily for **web (Chrome)** but also registered Android, iOS, macOS, and Windows for future use.
- Generated `lib/firebase_options.dart`, which is initialized in `main.dart`:
  ```dart
  import 'package:firebase_core/firebase_core.dart';
  import 'firebase_options.dart';

  void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const GreensWrldApp());
  }
  ```

---

## 2. Firebase Authentication

The app now supports:
1. **Email & Password login and sign-up**
2. **Google Sign-In (popup flow for web)**

Both **LoginPage** and **SignUpPage**:
- Include a **Google Sign-In button** using `FirebaseAuth.instance.signInWithPopup()`.
- Automatically redirect to **Home** if the user is already logged in.

### Dependencies added in `pubspec.yaml`:
```yaml
dependencies:
  firebase_core: ^3.15.1
  firebase_auth: ^5.6.2
```

---

## 3. Assets for Google Sign-In

- Added the Google logo:
  ```
  flutter_frontend/assets/images/google_logo.png
  ```
- Registered in `pubspec.yaml`:
  ```yaml
  flutter:
    uses-material-design: true
    assets:
      - assets/images/
  ```
- Used with:
  ```dart
  Image.asset('assets/images/google_logo.png', height: 20);
  ```

---

## 4. Navbar Updates

- Found in `lib/widgets/navbar.dart`.
- Behavior:
  - Shows **Login + Sign Up buttons** when the user is not logged in.
  - Shows **"Hi, email" + Logout** when the user is logged in.
- Logout logic:
  ```dart
  await FirebaseAuth.instance.signOut();
  Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
  ```

---

## 5. Pages Updated

### **LoginPage**
- Email/password login and Google login.
- Auto-redirects logged-in users to Home.
- Fixed layout issues:
  - Uses only one `Column`.
  - Sets `mainAxisSize: MainAxisSize.min` to prevent unbounded height issues.
  - Google button wrapped in `SizedBox` to avoid overflow.

### **SignUpPage**
- Email/password account creation and Google sign-up.
- Same layout fixes and style as LoginPage for consistency.
- Auto-redirects logged-in users to Home.

---

## 6. How to Run

1. Ensure **Flutter** and **Firebase CLI** are installed.
2. Start the frontend:
   ```bash
   cd frontend/flutter_frontend
   flutter clean
   flutter pub get
   flutter run -d chrome
   ```
3. **Login & Sign-Up pages** are routed as `/login` and `/signup`.
4. Navbar updates dynamically when logged in/out.
5. Logout will redirect users back to Home.

---

## Next Steps (Optional)

- Add **Google Sign-In support for Android/iOS** using the `google_sign_in` package.
- Add a **Profile Page** to display Firebase UID, email, and account info.
- Improve the **auth flow** with form validation, error messages, and loading states.

