import SwiftUI
import AuthenticationServices
import Supabase

struct AuthenticationView: View {
    @EnvironmentObject var appState: AppState
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.green.opacity(0.8), Color.blue.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // App Logo and Title
                VStack(spacing: 20) {
                    Image(systemName: "camera.on.rectangle")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                        .shadow(radius: 10)
                    
                    Text("Scenic")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Discover & Share Amazing Photo Spots")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Authentication Buttons
                VStack(spacing: 16) {
                    // Sign in with Apple
                    if Config.enableAppleSignIn {
                        SignInWithAppleButton(
                            .signIn,
                            onRequest: { request in
                                request.requestedScopes = [.fullName, .email]
                            },
                            onCompletion: { result in
                                handleSignInWithApple(result)
                            }
                        )
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 50)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                    }
                    
                    // Sign in with Google
                    Button(action: {
                        signInWithGoogle()
                    }) {
                        HStack {
                            Image(systemName: "globe")
                                .font(.system(size: 20))
                            
                            Text("Sign in with Google")
                                .font(.system(size: 19, weight: .medium))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                    }
                    .disabled(isLoading)
                    
                    // Continue as Guest
                    Button(action: {
                        continueAsGuest()
                    }) {
                        Text("Continue as Guest")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                            )
                    }
                    .disabled(isLoading)
                }
                .padding(.horizontal, 40)
                
                // Terms and Privacy
                VStack(spacing: 8) {
                    Text("By continuing, you agree to our")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    HStack(spacing: 4) {
                        Button("Terms of Service") {
                            // Open terms
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .underline()
                        
                        Text("and")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Button("Privacy Policy") {
                            // Open privacy
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .underline()
                    }
                }
                .padding(.bottom, 40)
            }
            
            // Loading overlay
            if isLoading {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    )
            }
        }
        .alert("Authentication Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An error occurred during authentication")
        }
    }
    
    // MARK: - Authentication Methods
    
    private func handleSignInWithApple(_ result: Result<ASAuthorization, Error>) {
        isLoading = true
        
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                guard let identityToken = appleIDCredential.identityToken,
                      let idTokenString = String(data: identityToken, encoding: .utf8) else {
                    showAuthError("Failed to get identity token")
                    return
                }
                
                Task {
                    do {
                        // Sign in with Supabase using Apple ID token
                        let session = try await supabase.auth.signInWithIdToken(
                            credentials: .init(
                                provider: .apple,
                                idToken: idTokenString
                            )
                        )
                        
                        await MainActor.run {
                            handleSuccessfulAuth(session: session)
                        }
                    } catch {
                        await MainActor.run {
                            showAuthError(error.localizedDescription)
                        }
                    }
                }
            }
            
        case .failure(let error):
            showAuthError(error.localizedDescription)
        }
    }
    
    private func signInWithGoogle() {
        isLoading = true
        
        Task {
            do {
                // Create a unique flow ID to track this authentication attempt
                let flowId = UUID().uuidString
                
                // Store the flow ID so we can verify the callback
                UserDefaults.standard.set(flowId, forKey: "pendingAuthFlow")
                
                // Get OAuth URL with PKCE enabled
                let url = try await supabase.auth.getOAuthSignInURL(
                    provider: .google,
                    scopes: "email profile",
                    redirectTo: URL(string: "scenic://auth-callback"),
                    queryParams: [
                        (name: "access_type", value: "offline"),
                        (name: "prompt", value: "consent"),
                        (name: "flow_id", value: flowId)
                    ]
                )
                
                await MainActor.run {
                    // Open in external browser instead of in-app
                    UIApplication.shared.open(url) { success in
                        if !success {
                            self.showAuthError("Could not open browser")
                        }
                        // Don't set isLoading = false here, wait for callback
                    }
                }
            } catch {
                await MainActor.run {
                    showAuthError(error.localizedDescription)
                }
            }
        }
    }
    
    private func continueAsGuest() {
        // For guest mode, we'll use anonymous authentication
        isLoading = true
        
        Task {
            do {
                let session = try await supabase.auth.signInAnonymously()
                
                await MainActor.run {
                    handleSuccessfulAuth(session: session, isGuest: true)
                }
            } catch {
                print("Anonymous auth error: \(error)")
                
                await MainActor.run {
                    // If anonymous auth fails, just proceed as guest without Supabase session
                    appState.isAuthenticated = true  // Changed to true to enter the app
                    appState.currentUser = User(
                        id: UUID(),
                        handle: "guest",
                        name: "Guest User",
                        email: "",
                        avatarUrl: nil,
                        bio: "",
                        reputationScore: 0,
                        homeRegion: "",
                        roles: [.guest],
                        badges: [],
                        followersCount: 0,
                        followingCount: 0,
                        spotsCount: 0,
                        createdAt: Date(),
                        updatedAt: Date()
                    )
                    isLoading = false
                }
            }
        }
    }
    
    private func handleSuccessfulAuth(session: Session, isGuest: Bool = false) {
        // Update app state with authenticated user
        appState.isAuthenticated = true
        
        // Create or update user in app state
        let user = session.user
        
        // Extract metadata values properly
        let handle = (user.userMetadata["handle"]?.value as? String) ?? user.email?.components(separatedBy: "@").first ?? "user"
        let fullName = (user.userMetadata["full_name"]?.value as? String) ?? "User"
        let avatarUrl = user.userMetadata["avatar_url"]?.value as? String
        let bio = (user.userMetadata["bio"]?.value as? String) ?? ""
        
        appState.currentUser = User(
            id: UUID(uuidString: user.id.uuidString) ?? UUID(),
            handle: handle,
            name: fullName,
            email: user.email ?? "",
            avatarUrl: avatarUrl,
            bio: bio,
            reputationScore: 0,
            homeRegion: "",
            roles: isGuest ? [.guest] : [.user],
            badges: [],
            followersCount: 0,
            followingCount: 0,
            spotsCount: 0,
            createdAt: user.createdAt,
            updatedAt: user.updatedAt
        )
        
        isLoading = false
    }
    
    private func showAuthError(_ message: String) {
        errorMessage = message
        showError = true
        isLoading = false
    }
}


#Preview {
    AuthenticationView()
        .environmentObject(AppState())
}