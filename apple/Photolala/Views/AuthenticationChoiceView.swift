import SwiftUI
import AuthenticationServices

struct AuthenticationChoiceView: View {
	@EnvironmentObject var identityManager: IdentityManager
	@Environment(\.dismiss) private var dismiss
	
	@State private var isShowingProviderSelection = false
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
				// Existing User Section
				VStack(spacing: 12) {
					Text("Already have an account?")
						.font(.headline)
						.foregroundColor(.secondary)
					
					Button(action: {
						authMode = .signIn
						isShowingProviderSelection = true
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
						authMode = .createAccount
						isShowingProviderSelection = true
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
				
				// Browse Locally Option
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
			.padding(.horizontal, 32)
			.padding(.bottom, 40)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Color(XPlatform.systemBackgroundColor))
		.sheet(isPresented: $isShowingProviderSelection) {
			ProviderSelectionView(
				authMode: authMode,
				onProviderSelected: handleProviderSelection,
				onError: handleError
			)
			.environmentObject(identityManager)
		}
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
		errorMessage = error.localizedDescription
		showError = true
		isShowingProviderSelection = false
	}
}

struct ProviderSelectionView: View {
	let authMode: AuthenticationChoiceView.AuthMode
	let onProviderSelected: (AuthProvider) -> Void
	let onError: (Error) -> Void
	
	@Environment(\.dismiss) private var dismiss
	@EnvironmentObject var identityManager: IdentityManager
	
	var body: some View {
		NavigationView {
			VStack(spacing: 24) {
				Text(authMode == .signIn ? "Sign in with" : "Create account with")
					.font(.title2)
					.fontWeight(.semibold)
					.padding(.top, 32)
				
				VStack(spacing: 16) {
					// Sign in with Apple button
					Button(action: {
						onProviderSelected(.apple)
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
						onError(AuthError.providerNotImplemented)
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
				}
				.padding(.horizontal, 32)
				
				Spacer()
			}
			#if os(iOS)
			.navigationBarItems(
				leading: Button("Cancel") {
					dismiss()
				}
			)
			#else
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") {
						dismiss()
					}
				}
			}
			#endif
		}
	}
}

// AuthProvider and AuthError are now in Models/AuthProvider.swift

#Preview {
	AuthenticationChoiceView()
		.environmentObject(IdentityManager())
}