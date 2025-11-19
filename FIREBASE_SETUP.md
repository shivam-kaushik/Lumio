# Firebase Authentication Setup Guide

This guide will help you set up Firebase Authentication for the Lumio app.

## Prerequisites

1. A Firebase account (create one at [firebase.google.com](https://firebase.google.com))
2. Flutter CLI installed
3. Firebase CLI installed (optional, but recommended)

## Step 1: Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project" or select an existing project
3. Follow the setup wizard
4. Enable **Authentication** in the Firebase Console:
   - Go to **Authentication** → **Get Started**
   - Enable **Email/Password** sign-in method

## Step 2: Add Firebase to Android

### Option A: Using Firebase CLI (Recommended)

1. Install Firebase CLI:
   ```bash
   npm install -g firebase-tools
   ```

2. Login to Firebase:
   ```bash
   firebase login
   ```

3. Add FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   ```

4. Configure Firebase for your project:
   ```bash
   flutterfire configure
   ```
   
   This will:
   - Detect your Firebase projects
   - Generate `firebase_options.dart` for each platform
   - Configure Android and iOS automatically

### Option B: Manual Setup

1. **Download `google-services.json`**:
   - In Firebase Console, go to **Project Settings** → **Your apps**
   - Click the Android icon (or add Android app if not added)
   - Register your app with package name: `com.example.lumio` (or your package name)
   - Download `google-services.json`
   - Place it in `android/app/`

2. **Update `android/build.gradle.kts`**:
   ```kotlin
   buildscript {
       dependencies {
           classpath("com.google.gms:google-services:4.4.0")
       }
   }
   ```

3. **Update `android/app/build.gradle.kts`**:
   ```kotlin
   plugins {
       id("com.android.application")
       id("kotlin-android")
       id("dev.flutter.flutter-gradle-plugin")
       id("com.google.gms.google-services") // Add this
   }
   ```

## Step 3: Add Firebase to iOS

1. **Download `GoogleService-Info.plist`**:
   - In Firebase Console, go to **Project Settings** → **Your apps**
   - Click the iOS icon (or add iOS app if not added)
   - Register your app with bundle ID
   - Download `GoogleService-Info.plist`
   - Place it in `ios/Runner/`

2. **Update `ios/Runner/AppDelegate.swift`**:
   ```swift
   import UIKit
   import Flutter
   import FirebaseCore // Add this

   @UIApplicationMain
   @objc class AppDelegate: FlutterAppDelegate {
     override func application(
       _ application: UIApplication,
       didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
     ) -> Bool {
       FirebaseApp.configure() // Add this
       GeneratedPluginRegistrant.register(with: self)
       return super.application(application, didFinishLaunchingWithOptions: launchOptions)
     }
   }
   ```

## Step 4: Verify Setup

1. Run the app:
   ```bash
   flutter run
   ```

2. Check the console for:
   - `✅ Firebase initialized successfully`

3. Try creating an account:
   - The app should show the login screen
   - Tap "Sign Up" to create a new account
   - Check Firebase Console → Authentication to see the new user

## Step 5: Configure Authentication Methods

In Firebase Console → Authentication → Sign-in method:

1. **Email/Password**: Already enabled (default)
2. **Google Sign-In** (optional): Enable if you want Google authentication
3. **Phone** (optional): Enable if you want phone authentication

## Troubleshooting

### Error: "Firebase initialization error"

- Make sure `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) is in the correct location
- Verify the package name/bundle ID matches Firebase project settings
- Run `flutter clean` and `flutter pub get`

### Error: "Email already in use"

- This is expected if the email is already registered
- Use "Forgot Password" to reset if needed

### Error: "Weak password"

- Firebase requires passwords to be at least 6 characters
- The app validates this, but Firebase may have additional requirements

## Next Steps

After authentication is working, you can:

1. **Add Cloud Firestore** for syncing reminders across devices
2. **Add user profiles** to store additional user information
3. **Implement social login** (Google, Apple, etc.)
4. **Add email verification** for new accounts

## Security Notes

- Never commit `google-services.json` or `GoogleService-Info.plist` to public repositories
- Use environment variables for sensitive Firebase config
- Enable Firebase App Check for production apps
- Set up proper Firebase Security Rules for Firestore

## Support

For issues:
1. Check Firebase Console for error logs
2. Review FlutterFire documentation: https://firebase.flutter.dev/
3. Check Firebase status: https://status.firebase.google.com/

