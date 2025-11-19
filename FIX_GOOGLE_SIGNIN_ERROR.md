# Fix Google Sign-In Error (ApiException: 10)

## Error Explanation

The error `ApiException: 10` (DEVELOPER_ERROR) means your app's SHA-1 certificate fingerprint is not registered in Firebase. This is required for Google Sign-In to work on Android.

## Quick Fix Steps

### Step 1: Get Your SHA-1 Certificate Fingerprint

**Option A: Using Flutter (Recommended)**

Run this command in your project root:

```bash
cd android
./gradlew signingReport
```

Look for the SHA-1 value under `Variant: debug` → `SHA1:` 

**Option B: Using keytool (Windows)**

```powershell
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

Look for the line that says `SHA1:` and copy the value (it looks like: `AA:BB:CC:DD:EE:FF:...`)

**Option C: Using keytool (macOS/Linux)**

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

### Step 2: Add SHA-1 to Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **lumio-44058**
3. Click the gear icon ⚙️ next to "Project Overview"
4. Select **Project settings**
5. Scroll down to **Your apps** section
6. Click on your **Android app** (package name: `com.example.lumio`)
7. Scroll down to **SHA certificate fingerprints**
8. Click **Add fingerprint**
9. Paste your SHA-1 certificate (the one you copied in Step 1)
10. Click **Save**

### Step 3: Download Updated google-services.json

After adding the SHA-1:

1. In the same Firebase Console page
2. Click **Download google-services.json**
3. Replace the existing file at `android/app/google-services.json` with the new one

### Step 4: Clean and Rebuild

```bash
flutter clean
flutter pub get
flutter run
```

### Step 5: Test Again

Try "Continue with Google" again. It should work now!

## For Release Builds

When you're ready to release your app, you'll need to add your **release keystore's SHA-1** as well:

1. Get SHA-1 from your release keystore:
   ```bash
   keytool -list -v -keystore <path-to-your-release-keystore> -alias <your-key-alias>
   ```

2. Add it to Firebase Console (same steps as above)

## Verify Configuration

To verify everything is set up correctly:

1. ✅ Google Sign-In is enabled in Firebase Console → Authentication → Sign-in method
2. ✅ SHA-1 certificate is added in Firebase Console → Project Settings → Your apps → Android app
3. ✅ Package name matches: `com.example.lumio`
4. ✅ `google-services.json` is in `android/app/` directory

## Still Having Issues?

If you're still getting errors after following these steps:

1. **Double-check the SHA-1**: Make sure you copied the entire SHA-1 value (it's long, about 40 characters with colons)

2. **Wait a few minutes**: Sometimes Firebase takes a few minutes to propagate changes

3. **Check Google Sign-In is enabled**: 
   - Firebase Console → Authentication → Sign-in method
   - Make sure Google is **Enabled** (toggle is ON)

4. **Verify package name**: 
   - Your `android/app/build.gradle.kts` should have: `applicationId = "com.example.lumio"`
   - This must match exactly in Firebase Console

5. **Check OAuth consent screen**:
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Select your project: **lumio-44058**
   - Navigate to **APIs & Services** → **OAuth consent screen**
   - Make sure it's configured (at least the basic info)

6. **Try a different device/emulator**: Sometimes cached credentials cause issues

## Common Mistakes

❌ **Wrong SHA-1**: Make sure you're using the SHA-1 from your debug keystore (not release)
❌ **Missing colons**: SHA-1 should include colons (e.g., `AA:BB:CC:...`)
❌ **Not waiting**: Firebase changes can take 1-2 minutes to propagate
❌ **Wrong package name**: Package name must match exactly between Firebase and your app

## Need Help?

If you're still stuck, check:
- Firebase Console → Authentication → Users (to see if sign-in attempts are being logged)
- Flutter logs for more detailed error messages
- Google Cloud Console → APIs & Services → Credentials (to verify OAuth client is set up)

