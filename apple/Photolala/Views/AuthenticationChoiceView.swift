import SwiftUI
import AuthenticationServices

struct AuthenticationChoiceView: View {
	@EnvironmentObject var identityManager: IdentityManager
	@Environment(\.dismiss) private var dismiss
	
	@State private var showingProviders = false
	@State private var authMode: AuthMode = .signIn
	@State private var showError = false
	@State private var errorMessage = ""
	
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
								.foregroundColor(.white)
								.frame(maxWidth: .infinity)
								.frame(height: 50)
								.background(Color.accentColor)
								.cornerRadius(10)
						}
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
								.foregroundColor(.white)
								.frame(maxWidth: .infinity)
								.frame(height: 50)
								.background(Color.accentColor)
								.cornerRadius(10)
						}
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
								.foregroundColor(.accentColor)
								.frame(maxWidth: .infinity)
								.frame(height: 50)
								.background(Color.accentColor.opacity(0.15))
								.cornerRadius(10)
						}
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
							.foregroundColor(.white)
							.frame(maxWidth: .infinity)
							.frame(height: 50)
							.background(Color.black)
							.cornerRadius(8)
						}
						
						// Google Sign-In button (placeholder for now)
						Button(action: {
							// TODO: Implement Google Sign-In in Phase 2
							handleError(AuthError.providerNotImplemented)
						}) {
							HStack {
								Image(systemName: "globe")
									.font(.title3)
								Text(authMode == .signIn ? "Sign in with Google" : "Sign up with Google")
									.font(.headline)
							}
							.foregroundColor(.black)
							.frame(maxWidth: .infinity)
							.frame(height: 50)
							.background(Color.gray.opacity(0.1))
							.overlay(
								RoundedRectangle(cornerRadius: 8)
									.stroke(Color.gray.opacity(0.3), lineWidth: 1)
							)
							.cornerRadius(8)
						}
						
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