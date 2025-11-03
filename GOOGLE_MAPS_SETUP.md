# Google Maps Setup Instructions

## Overview
The app now includes an interactive map view showing location-based reminders with geofences. To use this feature, you need to configure a Google Maps API key.

## Steps to Get Google Maps API Key

### 1. Create a Google Cloud Project
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the **Maps SDK for Android** and **Maps SDK for iOS** APIs

### 2. Get Your API Key
1. Go to **Credentials** in the Google Cloud Console
2. Click **Create Credentials** → **API Key**
3. Copy your API key

### 3. Configure Android
Edit `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
```
Replace `YOUR_GOOGLE_MAPS_API_KEY` with your actual API key.

### 4. Configure iOS
Edit `ios/Runner/AppDelegate.swift`:
```swift
import GoogleMaps

GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
```
Replace `YOUR_GOOGLE_MAPS_API_KEY` with your actual API key.

**Important**: Also add this in `ios/Runner/Info.plist`:
```xml
<key>GMSApiKey</key>
<string>YOUR_GOOGLE_MAPS_API_KEY</string>
```

### 5. Restrict Your API Key (Recommended)
1. In Google Cloud Console, click on your API key
2. Under **Application restrictions**, add:
   - **Android**: Add your app's package name and SHA-1 certificate fingerprint
   - **iOS**: Add your bundle identifier
3. Under **API restrictions**, restrict to:
   - Maps SDK for Android
   - Maps SDK for iOS

## Testing
After adding the API key, rebuild the app:
```bash
flutter clean
flutter pub get
flutter run
```

The Map tab should now display Google Maps with location-based reminders.

