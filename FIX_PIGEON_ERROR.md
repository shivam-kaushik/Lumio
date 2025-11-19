# Fix Google Sign-In PigeonUserDetails Error

## Error Explanation

The error `type 'List<Object?>' is not a subtype of type 'PigeonUserDetails?' in type cast` is a known bug in the `google_sign_in` plugin. It occurs when the plugin tries to cast a list to a single object internally.

## What We've Done

1. ✅ Updated `google_sign_in` to version `6.3.0` (latest stable)
2. ✅ Added sign-out before sign-in to clear cached state
3. ✅ Improved error handling to catch this specific error
4. ✅ Configured GoogleSignIn with explicit scopes

## Steps to Fix

### Step 1: Clean and Rebuild

```bash
flutter clean
flutter pub get
flutter run
```

### Step 2: Test Again

Try "Continue with Google" again. The sign-out before sign-in should help clear any cached state.

### Step 3: If Still Failing

If you're still getting the error, try these additional steps:

#### Option A: Uninstall and Reinstall App

```bash
# Uninstall the app from your device/emulator
adb uninstall com.example.lumio

# Then rebuild and install
flutter run
```

#### Option B: Clear App Data

1. Go to Android Settings → Apps → Lumio
2. Tap "Storage"
3. Tap "Clear Data"
4. Try Google Sign-In again

#### Option C: Use Different Google Account

Sometimes the error is account-specific. Try with a different Google account.

## Alternative: Use Firebase Auth Directly

If the plugin continues to have issues, we can implement Google Sign-In using Firebase Auth's built-in method instead of the `google_sign_in` package. This would require:

1. Using `signInWithPopup` or `signInWithRedirect` (web)
2. Or using native Android/iOS code directly

## Known Issues

This is a known issue in the `google_sign_in` plugin:
- GitHub Issue: https://github.com/flutter/flutter/issues/...
- The plugin sometimes has issues with cached authentication state
- The type casting error occurs in the plugin's internal Pigeon communication layer

## Workaround Status

The current implementation:
- Signs out before signing in (clears cached state)
- Uses explicit scopes
- Has better error handling

This should resolve the issue in most cases. If it persists, we may need to implement an alternative approach.

## Next Steps

1. Try the clean rebuild first
2. If it still fails, try uninstalling/reinstalling
3. If it continues, we can implement an alternative Google Sign-In method

