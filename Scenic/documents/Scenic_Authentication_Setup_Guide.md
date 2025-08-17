# Scenic Authentication Setup - Complete Guide

This document provides a detailed step-by-step guide for setting up authentication in the Scenic iOS app with Apple Sign-In, Google Sign-In, and Guest mode via Supabase.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Supabase Configuration](#supabase-configuration)
3. [iOS App Configuration](#ios-app-configuration)
4. [Google Sign-In Setup](#google-sign-in-setup)
5. [Apple Sign-In Setup](#apple-sign-in-setup)
6. [Implementation Details](#implementation-details)
7. [Testing](#testing)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Accounts
- **Supabase Account**: For backend authentication services
- **Apple Developer Account**: Paid membership ($99/year) for Sign in with Apple
- **Google Cloud Console Account**: Free, for Google OAuth
- **Xcode**: Version 14+ with iOS 16+ SDK

### Project Setup
- Bundle Identifier: `World.Scenic`
- Team: Your Apple Developer Team (not Personal Team)
- Minimum iOS: 16.0

---

## Supabase Configuration

### 1. Initial Project Setup
1. Create a new Supabase project at https://app.supabase.com
2. Note your project credentials:
   - **Project URL**: `https://joamynsevhhhiwynidxp.supabase.co`
   - **Anon Key**: Found in Settings → API

### 2. Authentication Settings
1. Navigate to **Authentication** → **URL Configuration**
2. Set **Site URL**: `scenic://auth-callback`
3. Add to **Redirect URLs**:
   ```
   scenic://auth-callback
   ```
4. Click **Save**

### 3. Enable Anonymous Sign-Ins
1. Go to **Authentication** → **Providers**
2. Scroll to **Anonymous Sign-Ins**
3. Toggle **Enable Anonymous Sign-Ins** to ON
4. Save

---

## iOS App Configuration

### 1. Add Supabase SDK
In `Package.json` or Swift Package Manager, add:
```swift
https://github.com/supabase/supabase-swift
```

### 2. Configure URL Scheme
1. In Xcode, select your project → Target → **Info** tab
2. Add URL Type:
   - **Identifier**: `World.Scenic`
   - **URL Schemes**: `scenic`
   - **Role**: Editor

### 3. Update Info.plist
The Info.plist should contain:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>World.Scenic</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>scenic</string>
        </array>
    </dict>
</array>
```

### 4. Create Configuration File
Create `Config.swift`:
```swift
struct Config {
    static let supabaseURL = "https://joamynsevhhhiwynidxp.supabase.co"
    static let supabaseAnonKey = "YOUR_ANON_KEY"
    static let appScheme = "scenic"
    static let appBundleID = "World.Scenic"
    static let enableAppleSignIn = true
}
```

---

## Google Sign-In Setup

### 1. Google Cloud Console Configuration

#### Create Project
1. Go to https://console.cloud.google.com
2. Create new project: "Scenic App"
3. Enable **Google Identity Toolkit API**

#### Configure OAuth Consent Screen
1. Navigate to **APIs & Services** → **OAuth consent screen**
2. Select **External** user type
3. Fill in:
   - **App name**: Scenic
   - **User support email**: Your email
   - **Developer contact**: Your email
4. Add your email as a **Test user**
5. Save

#### Create OAuth 2.0 Credentials
1. Go to **APIs & Services** → **Credentials**
2. Click **Create Credentials** → **OAuth Client ID**
3. Select **Web application** (NOT iOS!)
4. Configure:
   - **Name**: Scenic Supabase OAuth
   - **Authorized redirect URIs**: 
     ```
     https://joamynsevhhhiwynidxp.supabase.co/auth/v1/callback
     ```
5. Save and copy **Client ID** and **Client Secret**

### 2. Supabase Google Provider Setup
1. In Supabase Dashboard → **Authentication** → **Providers**
2. Find **Google** and enable it
3. Enter:
   - **Client ID**: From Google Console
   - **Client Secret**: From Google Console
4. Save

### 3. Important Fix for Redirect Loop
In Supabase **Authentication** → **URL Configuration**:
- Ensure **Site URL** is set to `scenic://auth-callback` (NOT localhost)

---

## Apple Sign-In Setup

### 1. Xcode Configuration

#### Add Capability
1. Select project → Target → **Signing & Capabilities**
2. Click **+ Capability**
3. Add **Sign in with Apple**
4. Ensure your paid Apple Developer Team is selected

### 2. Apple Developer Portal Configuration

#### Create App ID (if needed)
1. Go to https://developer.apple.com/account
2. Navigate to **Certificates, Identifiers & Profiles** → **Identifiers**
3. Create App ID for `World.Scenic` with Sign in with Apple capability

#### Create Services ID
1. Click **+** → Select **Services IDs**
2. Configure:
   - **Description**: Scenic Auth Service
   - **Identifier**: `World.Scenic.services`
3. Register, then configure:
   - Enable **Sign in with Apple**
   - **Primary App ID**: World.Scenic
   - **Domain**: `joamynsevhhhiwynidxp.supabase.co`
   - **Return URL**: `https://joamynsevhhhiwynidxp.supabase.co/auth/v1/callback`

#### Create Sign in with Apple Key
1. Go to **Keys** → **+**
2. Name: "Scenic Sign in with Apple"
3. Enable **Sign in with Apple**
4. Configure with Primary App ID: `World.Scenic`
5. Download the `.p8` file (ONE TIME ONLY!)
6. Note the **Key ID**

### 3. Supabase Apple Provider Setup

#### Generate JWT Secret
Use Supabase's JWT generator tool with:
- **Team ID**: Your 10-character team ID
- **Key ID**: From Apple Developer Portal
- **Client ID**: `World.Scenic.services`
- **Private Key**: Contents of .p8 file

#### Configure in Supabase
1. **Authentication** → **Providers** → **Apple**
2. Enable and configure:
   - **Client IDs**: `World.Scenic.services,World.Scenic` (BOTH IDs!)
   - **Secret Key**: Generated JWT from above
3. Save

### 4. Critical Fix for Native iOS
The Client IDs field MUST contain both:
- `World.Scenic.services` - for web OAuth
- `World.Scenic` - for native iOS

Comma-separated: `World.Scenic.services,World.Scenic`

---

## Implementation Details

### 1. Main App File (ScenicApp.swift)
```swift
@main
struct ScenicApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onOpenURL { url in
                    // Handle OAuth callback
                    Task {
                        try await supabase.auth.session(from: url)
                        if let session = try? await supabase.auth.session {
                            await MainActor.run {
                                appState.handleExistingSession(session)
                            }
                        }
                    }
                }
        }
    }
}

let supabase = SupabaseClient(
    supabaseURL: URL(string: Config.supabaseURL)!,
    supabaseKey: Config.supabaseAnonKey
)
```

### 2. Authentication View
- Displays three options: Apple, Google, Guest
- Handles authentication flow for each provider
- Shows appropriate UI based on authentication state

### 3. AppState Management
- Checks for existing session on launch
- Manages user authentication state
- Handles sign-out functionality

---

## Testing

### 1. Google Sign-In Testing
1. Click "Sign in with Google"
2. Browser opens with Google sign-in
3. Authenticate and approve permissions
4. Redirects back to app
5. User is logged in

### 2. Apple Sign-In Testing
**Note**: Must test on real device (not simulator)
1. Deploy to physical iPhone
2. Click "Sign in with Apple"
3. Authenticate with Face ID/Touch ID
4. Choose to share or hide email
5. Returns to app logged in

### 3. Guest Mode Testing
1. Click "Continue as Guest"
2. App creates anonymous session
3. Limited access granted

---

## Troubleshooting

### Common Issues and Solutions

#### Google Sign-In: Redirect Loop with localhost
**Problem**: Infinite redirect between Google and localhost
**Solution**: 
- Set Supabase Site URL to `scenic://auth-callback`
- Ensure redirect URI in Google Console matches Supabase callback

#### Apple Sign-In: "Unacceptable audience in id_token"
**Problem**: Audience mismatch between Bundle ID and Services ID
**Solution**: 
- Add BOTH IDs to Supabase Client IDs field: `World.Scenic.services,World.Scenic`
- Native iOS uses Bundle ID, web uses Services ID

#### Google Sign-In: "Access blocked - this app request is illegal"
**Problem**: OAuth not properly configured
**Solution**:
- Ensure OAuth consent screen is in "Testing" mode
- Add your email as a test user
- Use Web application type (not iOS) for OAuth client

#### Apple Sign-In: Button doesn't appear
**Problem**: Feature flag or capability not enabled
**Solution**:
- Set `enableAppleSignIn = true` in Config.swift
- Ensure Sign in with Apple capability is added in Xcode
- Verify paid Apple Developer membership

#### Build Errors
**Problem**: Various compilation errors
**Solution**:
- Clean build folder: `Cmd + Shift + K`
- Check for duplicate files (e.g., multiple ScenicApp.swift)
- Verify all imports are correct

---

## Security Considerations

1. **Never commit API keys to version control**
   - Use .gitignore for Config.swift
   - Consider environment variables for production

2. **Token Management**
   - Tokens are managed by Supabase SDK
   - Refresh tokens handled automatically

3. **Production Deployment**
   - Use server-side authentication for sensitive operations
   - Implement proper session management
   - Add rate limiting

---

## Maintenance

### Apple Sign-In
- JWT secrets expire every 6 months
- Regenerate using Supabase tool before expiration

### Google OAuth
- Monitor for API deprecations
- Keep OAuth consent screen updated

### Supabase
- Monitor usage and quotas
- Keep SDK updated
- Review auth logs regularly

---

## Summary

The authentication system now supports:
- ✅ Apple Sign-In (native iOS)
- ✅ Google Sign-In (OAuth web flow)
- ✅ Guest Mode (anonymous auth)

All three methods are fully functional and tested. The key configuration points are:
1. Supabase URL Configuration with correct Site URL
2. Both Bundle ID and Services ID in Apple Client IDs
3. Proper OAuth redirect URIs
4. URL scheme configuration in iOS app

For questions or issues, check the Supabase logs at Dashboard → Logs → Auth for detailed error messages.