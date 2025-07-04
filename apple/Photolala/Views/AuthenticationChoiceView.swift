import SwiftUI
import AuthenticationServices

struct AuthenticationChoiceView: View {
	@EnvironmentObject var identityManager: IdentityManager
	@Environment(\.dismiss) private var dismiss
	
	@State private var showingProviders = false
	@State private var authMode: AuthMode = .signIn
	@State private var showError = false
	@State private var errorMessage = ""
	@State private var showAccountLinking = false
	@State private var linkingData: (existingUser: PhotolalaUser, newCredential: AuthCredential)?
	@State private var showCreateAccountPrompt = false
	@State private var pendingProvider: AuthProvider?
	@State private var pendingCredential: AuthCredential?
	
	enum AuthMode {
		case signIn
		case createAccount
	}
	
	var body: some View {
		VStack(spacing: 0) {
			// Header
			VStack(spacing: 16) {
				Image(systemName: "photo.stack")
					.font(.system(size: 60))
					.foregroundColor(.accentColor)
				
				Text("Welcome to Photolala")
					.font(.largeTitle)
					.fontWeight(.bold)
				
				Text("Backup and browse your photos securely")
					.font(.headline)
					.foregroundColor(.secondary)
			}
			.padding(.top, 60)
			.padding(.bottom, 40)
			
			Spacer()
			
			// Authentication Options
			VStack(spacing: 24) {
				// Show sign out option if already signed in
				if identityManager.isSignedIn {
					VStack(spacing: 20) {
						// User info and sign out
						VStack(spacing: 16) {
							Image(systemName: "person.circle.fill")
								.font(.system(size: 60))
								.foregroundColor(.accentColor)
							
							if let user = identityManager.currentUser {
								Text("Signed in as")
									.font(.subheadline)
									.foregroundColor(.secondary)
								
								Text(user.displayName)
									.font(.headline)
									.foregroundColor(.primary)
							}
							
							Button(action: {
								identityManager.signOut()
								// Don't dismiss - let user see the sign in options
							}) {
								HStack {
									Image(systemName: "rectangle.portrait.and.arrow.right")
										.font(.callout)
									Text("Sign Out")
										.font(.callout)
								}
								.foregroundColor(.red)
							}
							.buttonStyle(.plain)
						}
						
						Divider()
							.frame(maxWidth: 200)
						
						// Continue button
						Button(action: {
							dismiss()
						}) {
							Text("Continue to Photos")
								.font(.headline)
								#if os(iOS)
								.foregroundColor(.white)
								.frame(maxWidth: .infinity)
								.frame(height: 50)
								.background(Color.accentColor)
								.cornerRadius(10)
								#else
								.frame(minWidth: 200)
								#endif
						}
						#if os(macOS)
						.buttonStyle(.borderedProminent)
						.controlSize(.large)
						#endif
					}
				} else if !showingProviders {
					// Initial buttons
					VStack(spacing: 12) {
						Text("Already have an account?")
							.font(.headline)
							.foregroundColor(.secondary)
						
						Button(action: {
							withAnimation(.easeInOut(duration: 0.3)) {
								authMode = .signIn
								showingProviders = true
							}
						}) {
							Text("Sign In")
								.font(.headline)
								#if os(iOS)
								.foregroundColor(.white)
								.frame(maxWidth: .infinity)
								.frame(height: 50)
								.background(Color.accentColor)
								.cornerRadius(10)
								#else
								.frame(minWidth: 200)
								#endif
						}
						#if os(macOS)
						.buttonStyle(.borderedProminent)
						.controlSize(.large)
						#endif
					}
					
					// Divider
					HStack {
						Rectangle()
							.fill(Color.secondary.opacity(0.3))
							.frame(height: 1)
						
						Text("OR")
							.font(.caption)
							.fontWeight(.medium)
							.foregroundColor(.secondary)
							.padding(.horizontal, 16)
						
						Rectangle()
							.fill(Color.secondary.opacity(0.3))
							.frame(height: 1)
					}
					.padding(.vertical, 8)
					
					// New User Section
					VStack(spacing: 12) {
						Text("New to Photolala?")
							.font(.headline)
							.foregroundColor(.secondary)
						
						Button(action: {
							withAnimation(.easeInOut(duration: 0.3)) {
								authMode = .createAccount
								showingProviders = true
							}
						}) {
							Text("Create Account")
								.font(.headline)
								#if os(iOS)
								.foregroundColor(.accentColor)
								.frame(maxWidth: .infinity)
								.frame(height: 50)
								.background(Color.accentColor.opacity(0.15))
								.cornerRadius(10)
								#else
								.frame(minWidth: 200)
								#endif
						}
						#if os(macOS)
						.buttonStyle(.bordered)
						.controlSize(.large)
						#endif
					}
				} else {
					// Provider selection
					VStack(spacing: 16) {
						Text(authMode == .signIn ? "Sign in with" : "Create account with")
							.font(.title2)
							.fontWeight(.semibold)
						
						// Sign in with Apple button
						Button(action: {
							handleProviderSelection(.apple)
						}) {
							HStack {
								Image(systemName: "applelogo")
								Text(authMode == .signIn ? "Sign in with Apple" : "Sign up with Apple")
									.font(.headline)
							}
							#if os(iOS)
							.foregroundColor(.white)
							.frame(maxWidth: .infinity)
							.frame(height: 50)
							.background(Color.black)
							.cornerRadius(8)
							#else
							.frame(minWidth: 280)
							#endif
						}
						#if os(macOS)
						.buttonStyle(.plain)
						.padding(.horizontal, 20)
						.padding(.vertical, 12)
						.background(Color.black)
						.foregroundColor(.white)
						.cornerRadius(8)
						#endif
						
						// Google Sign-In button
						Button(action: {
							handleProviderSelection(.google)
						}) {
							HStack {
								Image(systemName: "globe")
									.font(.title3)
								Text(authMode == .signIn ? "Sign in with Google" : "Sign up with Google")
									.font(.headline)
							}
							#if os(iOS)
							.foregroundColor(.black)
							.frame(maxWidth: .infinity)
							.frame(height: 50)
							.background(Color.gray.opacity(0.1))
							.overlay(
								RoundedRectangle(cornerRadius: 8)
									.stroke(Color.gray.opacity(0.3), lineWidth: 1)
							)
							.cornerRadius(8)
							#else
							.frame(minWidth: 280)
							#endif
						}
						#if os(macOS)
						.buttonStyle(.plain)
						.padding(.horizontal, 20)
						.padding(.vertical, 12)
						.background(Color(NSColor.controlBackgroundColor))
						.foregroundColor(.primary)
						.overlay(
							RoundedRectangle(cornerRadius: 8)
								.stroke(Color.gray.opacity(0.3), lineWidth: 1)
						)
						.cornerRadius(8)
						#endif
						
						// Back button
						Button(action: {
							withAnimation(.easeInOut(duration: 0.3)) {
								showingProviders = false
							}
						}) {
							Text("Back")
								.font(.callout)
								.foregroundColor(.accentColor)
						}
						.padding(.top, 8)
					}
				}
				
				// Browse Locally Option - only show when not signed in
				if !identityManager.isSignedIn {
					Button(action: {
						dismiss()
					}) {
						Text("Browse Locally Only")
							.font(.callout)
							.foregroundColor(.secondary)
							.underline()
					}
					.padding(.top, 8)
				}
				
				#if targetEnvironment(simulator) && DEBUG
				// Simulator testing option
				Button(action: {
					Task {
						await identityManager.mockSignIn()
						dismiss()
					}
				}) {
					Text("Use Test Account (Simulator)")
						.font(.caption)
						.foregroundColor(.orange)
				}
				.padding(.top, 4)
				#endif
			}
			.padding(.horizontal, 32)
			.padding(.bottom, 40)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Color(XPlatform.systemBackgroundColor))
		.alert("Authentication Error", isPresented: $showError) {
			Button("OK") {
				showError = false
			}
		} message: {
			Text(errorMessage)
		}
		.alert("No Account Found", isPresented: $showCreateAccountPrompt) {
			Button("Create Account") {
				// Use the existing credential if available to avoid re-authentication
				if let credential = pendingCredential {
					Task {
						do {
							_ = try await identityManager.createAccount(with: credential)
							dismiss()
						} catch {
							handleError(error)
						}
					}
				} else if let provider = pendingProvider {
					// Fallback to re-authentication if no credential is available
					authMode = .createAccount
					showingProviders = true
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
						handleProviderSelection(provider)
					}
				}
			}
			Button("Cancel", role: .cancel) {
				pendingProvider = nil
				pendingCredential = nil
			}
		} message: {
			if let provider = pendingProvider {
				Text("No account found with \(provider.displayName). Would you like to create a new account?")
			}
		}
		.sheet(isPresented: $showAccountLinking) {
			if let data = linkingData {
				AccountLinkingPrompt(
					existingUser: data.existingUser,
					newCredential: data.newCredential,
					onLink: {
						// Link the accounts
						Task {
							do {
								_ = try await identityManager.linkProvider(
									data.newCredential.provider,
									credential: data.newCredential,
									to: data.existingUser
								)
								dismiss()
							} catch {
								handleError(error)
							}
						}
						showAccountLinking = false
					},
					onCreateNew: {
						// Force create new account despite email match
						Task {
							do {
								_ = try await identityManager.forceCreateAccount(
									with: data.newCredential.provider,
									credential: data.newCredential
								)
								dismiss()
							} catch {
								handleError(error)
							}
						}
						showAccountLinking = false
					}
				)
			}
		}
	}
	
	private func handleProviderSelection(_ provider: AuthProvider) {
		Task {
			do {
				switch authMode {
				case .signIn:
					_ = try await identityManager.signIn(with: provider)
				case .createAccount:
					_ = try await identityManager.createAccount(with: provider)
				}
				dismiss()
			} catch {
				handleError(error)
			}
		}
	}
	
	private func handleError(_ error: Error) {
		// Don't show error for user cancellation
		if error is CancellationError {
			withAnimation(.easeInOut(duration: 0.3)) {
				showingProviders = false
			}
			return
		}
		
		// Check if it's a "no account found" error
		if case AuthError.noAccountFound(let provider, let credential) = error {
			pendingProvider = provider
			pendingCredential = credential
			showCreateAccountPrompt = true
			withAnimation(.easeInOut(duration: 0.3)) {
				showingProviders = false
			}
			return
		}
		
		// Check if it's an account linking scenario
		if case AuthError.emailAlreadyInUse(let existingUser, let newCredential) = error {
			linkingData = (existingUser, newCredential)
			showAccountLinking = true
			withAnimation(.easeInOut(duration: 0.3)) {
				showingProviders = false
			}
			return
		}
		
		errorMessage = error.localizedDescription
		showError = true
		withAnimation(.easeInOut(duration: 0.3)) {
			showingProviders = false
		}
	}
}

// AuthProvider and AuthError are now in Models/AuthProvider.swift

#Preview {
	AuthenticationChoiceView()
		.environmentObject(IdentityManager())
}