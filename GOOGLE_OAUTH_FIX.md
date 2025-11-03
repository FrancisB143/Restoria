# Fix Google OAuth "Couldn't sign you in" Error

## The Problem
You're seeing **"This browser or app may not be secure"** error when trying to sign in with Google. This happens because Google doesn't trust embedded WebViews for security reasons.

## Root Causes
1. ❌ Using embedded WebView (not secure)
2. ❌ Missing redirect URI configuration in Supabase
3. ❌ Google OAuth credentials not properly configured for Flutter apps

---

## Solution Steps

### Step 1: Configure Supabase OAuth Settings

1. Go to your **Supabase Dashboard**
2. Navigate to **Authentication** → **URL Configuration**
3. Add these **Redirect URLs**:
   ```
   io.supabase.restoria://login-callback
   https://your-project.supabase.co/auth/v1/callback
   ```
4. Click **Save**

---

### Step 2: Configure Google Cloud Console

#### For Web (Already Done)
Your web configuration should already be working.

#### For Mobile Apps (IMPORTANT)
You need to add OAuth client IDs for iOS and Android:

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Go to **APIs & Services** → **Credentials**
4. Click **+ CREATE CREDENTIALS** → **OAuth client ID**

##### For Android:
- Application type: **Android**
- Name: `Restoria Android`
- Package name: `com.yourcompany.restoria` (check `android/app/build.gradle.kts`)
- SHA-1 certificate fingerprint: Get it by running:
  ```bash
  cd android
  ./gradlew signingReport
  ```
  Copy the SHA-1 from the debug keystore

##### For iOS (if needed):
- Application type: **iOS**
- Name: `Restoria iOS`
- Bundle ID: `com.yourcompany.restoria` (check `ios/Runner.xcodeproj`)

---

### Step 3: Update Android Configuration

#### android/app/build.gradle.kts

Make sure your package name matches the one in Google Cloud Console:

```kotlin
android {
    namespace = "com.yourcompany.restoria"  // Must match Google Console
    // ...
}
```

#### android/app/src/main/AndroidManifest.xml

Add deep link intent filter for OAuth callback:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application>
        <activity
            android:name=".MainActivity"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            
            <!-- Regular launcher intent -->
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
            
            <!-- Deep link for OAuth callback -->
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                
                <!-- Deep link scheme -->
                <data
                    android:scheme="io.supabase.restoria"
                    android:host="login-callback" />
            </intent-filter>
            
        </activity>
    </application>
</manifest>
```

---

### Step 4: Update Supabase Configuration

#### lib/config/supabase_config.dart

Make sure your Supabase config is correct:

```dart
class SupabaseConfig {
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_ANON_KEY';
}
```

---

### Step 5: Test the Fix

1. **Clean and rebuild** your app:
   ```bash
   flutter clean
   flutter pub get
   cd android && ./gradlew clean && cd ..
   flutter run
   ```

2. Try logging in with Google:
   - Click "Continue with Google"
   - It should open your **system browser** (Chrome/Edge)
   - Sign in with Google there
   - It will redirect back to your app

---

## Alternative Solution: Use url_launcher

If the above doesn't work, you can use `url_launcher` package for more control:

### Add to pubspec.yaml:
```yaml
dependencies:
  url_launcher: ^6.2.1
```

### Update the Google Sign-In method:
```dart
Future<void> _handleGoogleSignIn(BuildContext context) async {
  setState(() => _isLoading = true);

  try {
    // Get OAuth URL from Supabase
    final response = await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.restoria://login-callback',
      authScreenLaunchMode: LaunchMode.externalApplication,
    );

    // Auth state listener will handle the callback
  } catch (e) {
    _showError('Google sign-in failed: $e');
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}
```

---

## Verification Checklist

After completing the steps above, verify:

- [ ] ✅ Supabase redirect URL includes `io.supabase.restoria://login-callback`
- [ ] ✅ Google Cloud Console has OAuth client IDs for Android (and iOS if needed)
- [ ] ✅ AndroidManifest.xml has deep link intent filter
- [ ] ✅ Package name matches across all configurations
- [ ] ✅ App opens **system browser** (not embedded WebView) when clicking Google sign-in
- [ ] ✅ After signing in with Google in browser, it redirects back to your app
- [ ] ✅ User is successfully logged in

---

## Still Having Issues?

### Check Supabase Logs:
1. Go to Supabase Dashboard → **Logs** → **Auth**
2. Look for errors when attempting Google sign-in

### Check Flutter Console:
```bash
flutter run
```
Look for any OAuth-related errors in the console.

### Common Errors:

**"redirect_uri_mismatch"**
- Make sure redirect URI in Supabase matches the one in Google Cloud Console

**"Package name mismatch"**
- Verify `android/app/build.gradle.kts` package name matches Google Cloud Console

**"App opens browser but doesn't return"**
- Check that deep link intent filter is correctly configured in AndroidManifest.xml
- Verify the scheme matches: `io.supabase.restoria://login-callback`

---

## Why This Happens

Google blocks OAuth in embedded WebViews because:
1. 🔒 **Security**: Embedded WebViews can be manipulated
2. 🔒 **Phishing Protection**: Prevents fake login screens
3. 🔒 **User Safety**: System browser shows actual Google.com URL

The solution is to use the **system browser** (Chrome/Edge/Safari) which Google trusts.

---

## Quick Test

Run this command to test deep links:
```bash
# Android
adb shell am start -a android.intent.action.VIEW -d "io.supabase.restoria://login-callback"
```

If your app opens, deep linking is configured correctly! ✅
