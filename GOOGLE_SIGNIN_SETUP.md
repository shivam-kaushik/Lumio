# Google Sign-In Setup Guide

This guide will help you enable Google Sign-In for your Lumio app.

## Prerequisites

1. Firebase project already configured (see `FIREBASE_SETUP.md`)
2. Google Sign-In package installed (already added to `pubspec.yaml`)

## Step 1: Enable Google Sign-In in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **lumio-44058**
3. Navigate to **Authentication** → **Sign-in method**
4. Click on **Google** in the providers list
5. Toggle **Enable** to ON
6. Enter your **Project support email** (your email address)
7. Click **Save**

## Step 2: Configure OAuth Consent Screen (if needed)

If you haven't set up OAuth consent screen:

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project: **lumio-44058**
3. Navigate to **APIs & Services** → **OAuth consent screen**
4. Choose **External** (unless you have a Google Workspace)
5. Fill in the required information:
   - **App name**: Lumio
   - **User support email**: Your email
   - **Developer contact information**: Your email
6. Add scopes (if needed):
   - `email`
   - `profile`
   - `openid`
7. Add test users (optional, for testing)
8. Click **Save and Continue**

## Step 3: Configure SHA-1 Certificate (Android)

For Android, you need to add your app's SHA-1 fingerprint to Firebase:

### Get SHA-1 Certificate

**For Debug Build:**
```bash
# Windows
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android

# macOS/Linux
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

**For Release Build:**
```bash
keytool -list -v -keystore <path-to-your-keystore> -alias <your-key-alias>
```

### Add SHA-1 to Firebase

1. Copy the SHA-1 fingerprint (look for "SHA1:" in the output)
2. Go to Firebase Console → **Project Settings** → **Your apps**
3. Select your Android app
4. Click **Add fingerprint**
5. Paste the SHA-1 certificate
6. Click **Save**

## Step 4: Configure iOS (if needed)

For iOS, Google Sign-In should work automatically if:
- `GoogleService-Info.plist` is properly configured
- The bundle ID matches your Firebase project

## Step 5: Test Google Sign-In

1. Run your app:
   ```bash
   flutter run
   ```

2. On the login screen, tap **"Continue with Google"**
3. Select your Google account
4. Grant permissions if prompted
5. You should be signed in and redirected to the main app

## Troubleshooting

### Error: "Google sign-in is not enabled"

- Make sure Google Sign-In is enabled in Firebase Console
- Check that you've saved the changes in Firebase Console

### Error: "DEVELOPER_ERROR" (Android)

- Make sure you've added the SHA-1 certificate to Firebase
- Verify the package name matches: `com.example.lumio`
- Try running `flutter clean` and rebuilding

### Error: "Sign in canceled"

- This is normal if the user cancels the sign-in flow
- No error message will be shown to the user

### Error: "Account exists with different credential"

- This means the email is already registered with email/password
- User should sign in with email/password instead
- Or link accounts in Firebase Console

### iOS: "Sign in failed"

- Make sure `GoogleService-Info.plist` is in `ios/Runner/`
- Verify the bundle ID matches Firebase configuration
- Check that Google Sign-In is enabled in Firebase Console

## Additional Configuration

### Custom Google Sign-In Scopes

If you need additional scopes, modify `lib/core/services/auth_service.dart`:

```dart
final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: ['email', 'profile', 'openid'],
);
```

### Web Configuration

For web support, you'll need to:
1. Configure OAuth 2.0 Client IDs in Google Cloud Console
2. Add authorized JavaScript origins
3. Add authorized redirect URIs

## Security Notes

- Never commit SHA-1 certificates or keystores to version control
- Use different SHA-1 certificates for debug and release builds
- Keep your OAuth client secrets secure
- Regularly rotate OAuth credentials in production

## Support

For issues:
1. Check Firebase Console → Authentication → Users for sign-in attempts
2. Review Google Cloud Console → APIs & Services → Credentials
3. Check Flutter logs for detailed error messages
4. Review Firebase documentation: https://firebase.google.com/docs/auth

