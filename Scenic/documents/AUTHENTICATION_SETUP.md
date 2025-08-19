# Authentication Setup Guide

This guide explains how to set up authentication for the Scenic app with Apple Sign-In and Google Sign-In via Supabase.

## Prerequisites

1. Supabase project (already created)
2. Apple Developer account
3. Google Cloud Console account

## 1. Configure Supabase Credentials

1. Open `Scenic/Configuration/Config.swift`
2. Replace the placeholder values with your actual Supabase credentials:
   - `supabaseURL`: Your Supabase project URL
   - `supabaseAnonKey`: Your Supabase anonymous key

## 2. Configure Sign in with Apple

### In Xcode:

1. Select the Scenic project in the navigator
2. Select the Scenic target
3. Go to "Signing & Capabilities" tab
4. Click "+ Capability"
5. Add "Sign in with Apple"
6. Ensure your Apple Developer account is selected for signing

### In Supabase Dashboard:

1. Go to Authentication → Providers
2. Enable "Apple" provider
3. Configure the following:
   - **Services ID**: Your app's bundle ID (com.scenic.app)
   - **Secret Key**: Generate from Apple Developer Console
   - **Key ID**: From Apple Developer Console
   - **Team ID**: Your Apple Developer Team ID

### In Apple Developer Console:

1. Create a Services ID for your app
2. Enable Sign in with Apple
3. Configure Return URLs to include: `https://YOUR_PROJECT_ID.supabase.co/auth/v1/callback`
4. Create a Sign in with Apple key
5. Download the key and note the Key ID

## 3. Configure Google Sign-In

### In Google Cloud Console:

1. Create a new project or select existing
2. Enable Google Sign-In API
3. Create OAuth 2.0 credentials:
   - Application type: iOS
   - Bundle ID: com.scenic.app
4. Download the configuration file (GoogleService-Info.plist)
5. Add the plist file to your Xcode project

### In Supabase Dashboard:

1. Go to Authentication → Providers
2. Enable "Google" provider
3. Add your OAuth credentials:
   - **Client ID**: From Google Cloud Console
   - **Client Secret**: From Google Cloud Console

### Configure URL Scheme:

1. In Xcode, select the project
2. Select the target
3. Go to "Info" tab
4. Add URL Type:
   - URL Schemes: `scenic`
   - This allows the app to handle `scenic://auth-callback`

## 4. Testing Authentication

### Test Sign in with Apple:

1. Run the app on a real device or simulator
2. Tap "Sign in with Apple"
3. Complete the authentication flow
4. Verify user is logged in

### Test Google Sign-In:

1. Run the app
2. Tap "Sign in with Google"
3. Complete OAuth flow in browser
4. App should receive callback and log user in

### Test Guest Mode:

1. Run the app
2. Tap "Continue as Guest"
3. Verify limited access mode

## 5. Security Considerations

1. **Never commit real API keys** to version control
2. Use `.gitignore` to exclude Config.swift or use environment variables
3. For production:
   - Use server-side authentication for sensitive operations
   - Implement proper session management
   - Add rate limiting
   - Use iOS Keychain for storing tokens

## 6. Troubleshooting

### Sign in with Apple issues:

- Ensure capability is enabled in Xcode
- Verify bundle ID matches in all configurations
- Check provisioning profile includes Sign in with Apple

### Google Sign-In issues:

- Verify URL scheme is configured
- Check OAuth redirect URLs in Google Console
- Ensure GoogleService-Info.plist is added to project

### General issues:

- Check Supabase logs for authentication errors
- Verify network connectivity
- Ensure all providers are enabled in Supabase dashboard

## 7. Next Steps

1. Implement user profile synchronization
2. Add social features (following, sharing)
3. Implement role-based access control
4. Add biometric authentication option
5. Implement session persistence