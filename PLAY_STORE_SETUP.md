# Play Store Publishing Setup Guide

This guide will help you prepare your Lumio app for Google Play Store publishing.

## ✅ Completed Steps

1. ✅ Package name changed from `com.example.lumio` to `com.lumio.app`
2. ✅ All Kotlin files updated with new package name
3. ✅ Method channel names updated
4. ✅ Build configuration updated for release signing
5. ✅ Key.properties template created

## 📋 Next Steps

### Step 1: Create Your Keystore

**On Windows (PowerShell):**
```powershell
keytool -genkey -v -keystore $env:USERPROFILE\lumio-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias lumio
```

**On Mac/Linux:**
```bash
keytool -genkey -v -keystore ~/lumio-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias lumio
```

**Important:**
- Remember the passwords you enter (keystore password and key password)
- Keep the keystore file safe - you'll need it for all future updates
- The alias is `lumio` (as configured in build.gradle.kts)

### Step 2: Configure key.properties

1. Copy the template file:
   ```bash
   cp android/key.properties.template android/key.properties
   ```

2. Edit `android/key.properties` and fill in your values:
   ```properties
   storePassword=YourActualKeystorePassword
   keyPassword=YourActualKeyPassword
   keyAlias=lumio
   storeFile=C:\\Users\\YourName\\lumio-release-key.jks
   ```
   
   **Windows example:**
   ```properties
   storeFile=C:\\Users\\YourName\\lumio-release-key.jks
   ```
   
   **Mac/Linux example:**
   ```properties
   storeFile=/Users/YourName/lumio-release-key.jks
   ```

3. **IMPORTANT:** Add `android/key.properties` to `.gitignore` to keep your passwords safe!

### Step 3: Update Firebase Configuration

Since you changed the package name, you need to:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (`lumio-44058`)
3. Go to Project Settings → Your apps
4. Add a new Android app with package name: `com.lumio.app`
5. Download the new `google-services.json`
6. Replace `android/app/google-services.json` with the new file

**OR** update the existing Android app's package name in Firebase Console (if supported).

### Step 4: Build Release App Bundle

```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

The AAB file will be at:
```
build/app/outputs/bundle/release/app-release.aab
```

### Step 5: Test the Release Build

Before uploading to Play Store, test the release build:

```bash
flutter build apk --release
flutter install --release
```

Test all major features to ensure everything works.

### Step 6: Update App Version

Before each release, update the version in `pubspec.yaml`:

```yaml
version: 1.0.0+1  # Format: versionName+versionCode
```

- `versionName` (1.0.0): User-facing version
- `versionCode` (+1): Must increase with each Play Store upload

### Step 7: Create Google Play Console Account

1. Go to https://play.google.com/console
2. Pay the one-time $25 registration fee
3. Complete account setup

### Step 8: Create Your App

1. Click "Create app"
2. Fill in:
   - App name: **Lumio**
   - Default language: English
   - App or Game: **App**
   - Free or Paid: **Free**
3. Click "Create app"

### Step 9: Complete Store Listing

Required items:
- ✅ App icon (512x512 PNG)
- ✅ Feature graphic (1024x500 PNG)
- ✅ Screenshots (at least 2, up to 8)
  - Phone: 16:9 or 9:16 ratio
  - Min 320px, max 3840px
- ✅ Short description (80 chars max)
- ✅ Full description (4000 chars max)
- ✅ Privacy policy URL (required if you collect data)

### Step 10: Complete App Content

1. **Data Safety Form** - Declare what data you collect
2. **Target Audience** - Select appropriate age range
3. **Content Rating** - Complete questionnaire
4. **Export Compliance** - If applicable

### Step 11: Upload and Publish

1. Go to **Production** → **Create new release**
2. Upload your `app-release.aab` file
3. Add release notes
4. Review and save
5. Click **"Start rollout to Production"**

## ⚠️ Important Notes

1. **Package Name**: Once published, you CANNOT change `com.lumio.app`. Make sure this is what you want.

2. **Version Code**: Must increase with each update (1, 2, 3, etc.)

3. **Keystore**: Keep it safe! You'll need it for all future updates. If you lose it, you can't update your app.

4. **Privacy Policy**: Required if you collect any user data (Firebase, location, etc.)

5. **Testing**: Consider using Internal Testing or Closed Testing tracks first before Production.

## 🔒 Security Checklist

- [ ] `key.properties` is in `.gitignore`
- [ ] Keystore file is backed up securely
- [ ] Passwords are stored securely (password manager)
- [ ] `google-services.json` is updated for new package name

## 📝 Current Configuration

- **Package Name**: `com.lumio.app`
- **Namespace**: `com.lumio.app`
- **App Version**: `1.0.0+1` (check `pubspec.yaml`)
- **Min SDK**: Check `android/app/build.gradle.kts`
- **Target SDK**: Check `android/app/build.gradle.kts`

## 🆘 Troubleshooting

### Build fails with "key.properties not found"
- Make sure you created `android/key.properties` from the template
- Check that the file path is correct

### "Package name mismatch" error
- Verify `applicationId` in `build.gradle.kts` is `com.lumio.app`
- Check Firebase `google-services.json` matches the package name

### "Keystore password incorrect"
- Double-check your passwords in `key.properties`
- Make sure there are no extra spaces or special characters

## 📞 Need Help?

If you encounter issues:
1. Check the error message carefully
2. Verify all file paths are correct
3. Ensure Firebase is configured for the new package name
4. Test with a debug build first: `flutter build apk --debug`

Good luck with your Play Store launch! 🚀

