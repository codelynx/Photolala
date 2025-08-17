import SwiftUI
import XPlatform
import AuthenticationServices

struct AuthenticationChoiceView: View {
	@EnvironmentObject var identityManager: IdentityManager
	@Environment(\.dismiss) private var dismiss
	
	@State private var showError = false
	@State private var errorMessage = ""
	@State private var showAccountLinking = false
	@State private var linkingData: (existingUser: PhotolalaUser, newCredential: AuthCredential)?
	@State private var showCreateAccountPrompt = false
	@State private var pendingProvider: AuthProvider?
	@State private var pendingCredential: AuthCredential?
	
	var body: some View {
		VStack(spacing: 0) {
			// Header
			VStack(spacing: 16) {
				if let appIcon = XImage(named: "AppIconImage") {
					Image(appIcon)
						.resizable()
						.aspectRatio(contentMode: .fit)
						.frame(width: 80, height: 80)
						.cornerRadius(16)
				} else {
					Image(systemName: "photo.stack")
						.font(.system(size: 80))
						.foregroundColor(.accentColor)
				}
				
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
				} else {
					// Main authentication view with providers
					VStack(spacing: 16) {
						// Sign in with Apple button
						Button(action: {
							handleProviderSelection(.apple)
						}) {
							HStack {
								Image(systemName: "applelogo")
								Text("Continue with Apple")
									.font(.headline)
							}
							#if os(iOS)
							.foregroundColor(.white)
							.frame(maxWidth: .infinity)
							.frame(height: 50)
							.background(Color.black)
							.cornerRadius(25)
							#else
							.frame(minWidth: 350, maxWidth: 350)
							#endif
						}
						#if os(macOS)
						.buttonStyle(.plain)
						.padding(.horizontal, 20)
						.padding(.vertical, 12)
						.background(Color.black)
						.foregroundColor(.white)
						.cornerRadius(25)
						#endif
						
						// Google Sign-In button
						Button(action: {
							handleProviderSelection(.google)
						}) {
							HStack {
								Image(systemName: "globe")
									.font(.title3)
								Text("Continue with Google")
									.font(.headline)
							}
							#if os(iOS)
							.foregroundColor(.black)
							.frame(maxWidth: .infinity)
							.frame(height: 50)
							.background(Color.white)
							.overlay(
								RoundedRectangle(cornerRadius: 25)
									.stroke(Color.gray.opacity(0.3), lineWidth: 1)
							)
							.cornerRadius(25)
							#else
							.frame(minWidth: 350, maxWidth: 350)
							#endif
						}
						#if os(macOS)
						.buttonStyle(.plain)
						.padding(.horizontal, 20)
						.padding(.vertical, 12)
						.background(Color(NSColor.controlBackgroundColor))
						.foregroundColor(.primary)
						.overlay(
							RoundedRectangle(cornerRadius: 25)
								.stroke(Color.gray.opacity(0.3), lineWidth: 1)
						)
						.cornerRadius(25)
						#endif
						
						// Helpful text
						VStack(spacing: 8) {
							Rectangle()
								.fill(Color.secondary.opacity(0.3))
								.frame(height: 1)
								.frame(maxWidth: 350)
								.padding(.vertical, 16)
							
							Text("Sign in to your existing account or create a new one")
								.font(.caption)
								.foregroundColor(.secondary)
								.multilineTextAlignment(.center)
							
							Text("We'll automatically detect if you have an account")
								.font(.caption2)
								.foregroundColor(.secondary.opacity(0.8))
								.multilineTextAlignment(.center)
						}
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
		.background(Color(XColor.systemBackground))
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
					Task {
						do {
							_ = try await identityManager.createAccount(with: provider)
							dismiss()
						} catch {
							handleError(error)
						}
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
				// Try to sign in first (auto-detection)
				_ = try await identityManager.signIn(with: provider)
				dismiss()
			} catch {
				// Handle specific error cases
				if case AuthError.noAccountFound(let provider, let credential) = error {
					// No account exists - offer to create one
					pendingProvider = provider
					pendingCredential = credential
					showCreateAccountPrompt = true
				} else {
					// Other errors (like account already exists when trying to create)
					handleError(error)
				}
			}
		}
	}
	
	private func handleError(_ error: Error) {
		// Don't show error for user cancellation
		if error is CancellationError {
			return
		}
		
		// Check if it's a "no account found" error
		if case AuthError.noAccountFound(let provider, let credential) = error {
			pendingProvider = provider
			pendingCredential = credential
			showCreateAccountPrompt = true
			return
		}
		
		// Check if it's an account linking scenario
		if case AuthError.emailAlreadyInUse(let existingUser, let newCredential) = error {
			linkingData = (existingUser, newCredential)
			showAccountLinking = true
			return
		}
		
		errorMessage = error.localizedDescription
		showError = true
	}
}

// AuthProvider and AuthError are now in Models/AuthProvider.swift

#Preview {
	AuthenticationChoiceView()
		.environmentObject(IdentityManager())
}
