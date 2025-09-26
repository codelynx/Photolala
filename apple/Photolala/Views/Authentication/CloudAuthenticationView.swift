//
//  CloudAuthenticationView.swift
//  Photolala
//
//  Sign-in view for cloud authentication
//

import SwiftUI
import GoogleSignInSwift

enum SignupState {
	case signIn
	case noAccount
	case termsAcceptance
	case welcome
}

struct CloudAuthenticationView: View {
	@Binding var isPresented: Bool
	@StateObject private var accountManager = AccountManager.shared

	@State private var isSigningIn = false
	@State private var errorMessage: String?
	@State private var showError = false
	@State private var signupState: SignupState = .signIn
	@State private var pendingProvider: String?
	@State private var pendingOAuthTokens: OAuthTokens?

	var body: some View {
		Group {
			switch signupState {
			case .signIn:
				signInView
			case .noAccount:
				NoAccountView(
					providerName: pendingProvider ?? "Provider",
					onCreateAccount: {
						withAnimation {
							signupState = .termsAcceptance
						}
					},
					onCancel: {
						// Clear pending data and return to sign-in
						pendingProvider = nil
						pendingOAuthTokens = nil
						withAnimation {
							signupState = .signIn
						}
					}
				)
			case .termsAcceptance:
				TermsAcceptanceView(
					onAccept: {
						Task {
							await createAccount()
						}
					},
					onDecline: {
						// Return to sign-in
						pendingProvider = nil
						pendingOAuthTokens = nil
						withAnimation {
							signupState = .signIn
						}
					}
				)
			case .welcome:
				WelcomeView(
					userName: accountManager.currentUser?.displayName ?? "User",
					onGetStarted: {
						// Dismiss the authentication view - user will see Home screen
						isPresented = false
					}
				)
			}
		}
		.animation(.easeInOut(duration: 0.3), value: signupState)
	}

	private var signInView: some View {
		VStack(spacing: 30) {
			// Header
			VStack(spacing: 10) {
				Image(systemName: "icloud.circle.fill")
					.font(.system(size: 80))
					.foregroundStyle(.blue.gradient)

				Text("Sign in to Photolala Cloud")
					.font(.largeTitle)
					.bold()

				Text("Access your photos from anywhere")
					.font(.headline)
					.foregroundColor(.secondary)
			}
			.padding(.top, 40)

			// Sign-in options
			VStack(spacing: 16) {
				// Google Sign-In
				GoogleSignInButton(viewModel: GoogleSignInButtonViewModel(
					scheme: .dark,
					style: .wide,
					state: .normal
				)) {
					Task { @MainActor in
						await signInWithGoogle()
					}
				}
				.frame(height: 50)
				.disabled(isSigningIn)

				// Apple Sign-In
				Button(action: {
					Task { @MainActor in
						await signInWithApple()
					}
				}) {
					HStack {
						Image(systemName: "applelogo")
							.font(.title3)
						Text("Sign in with Apple")
							.font(.headline)
					}
					.frame(maxWidth: .infinity)
					.frame(height: 50)
					.background(Color.black)
					.foregroundColor(.white)
					.cornerRadius(8)
				}
				.disabled(isSigningIn)

				if isSigningIn {
					ProgressView("Signing in...")
						.padding(.top)
				}
			}
			.padding(.horizontal, 40)

			Spacer()

			// Cancel button
			Button("Cancel") {
				isPresented = false
			}
			.buttonStyle(.plain)
			.foregroundColor(.secondary)
			.padding(.bottom)
		}
		.frame(width: 450, height: 500)
		.alert("Sign-In Error", isPresented: $showError) {
			Button("OK") {
				errorMessage = nil
			}
		} message: {
			Text(errorMessage ?? "An unknown error occurred")
		}
		.onChange(of: accountManager.isSignedIn) { oldValue, newValue in
			print("[CloudAuthenticationView] isSignedIn changed from \(oldValue) to \(newValue)")
			if newValue {
				print("[CloudAuthenticationView] User signed in, dismissing view")
				// Dismiss on successful sign-in
				isPresented = false
			}
		}
		.onAppear {
			print("[CloudAuthenticationView] View appeared, isSignedIn: \(accountManager.isSignedIn)")
			// If already signed in when view appears, dismiss immediately
			if accountManager.isSignedIn {
				print("[CloudAuthenticationView] Already signed in, dismissing view")
				isPresented = false
			}
		}
		.onDisappear {
			print("[CloudAuthenticationView] View disappeared")
		}
	}

	// MARK: - Actions

	private func signInWithGoogle() async {
		print("[CloudAuthenticationView] Starting Google sign-in")
		isSigningIn = true
		defer {
			isSigningIn = false
			print("[CloudAuthenticationView] Google sign-in completed, isSigningIn = false")
		}

		do {
			// First get OAuth tokens
			let oauthResult = try await accountManager.authenticateWithGoogle()

			// Check if account exists
			let accountExists = try await accountManager.checkAccountExists(
				provider: "google",
				oauthTokens: oauthResult
			)

			if accountExists {
				// Existing user - sign in normally
				let user = try await accountManager.completeSignIn(
					provider: "google",
					oauthTokens: oauthResult
				)
				print("[CloudAuthenticationView] Google sign-in successful, existing user: \(user.displayName)")

				// Dismiss to show home screen
				await MainActor.run {
					isPresented = false
				}
			} else {
				// New user - show signup flow
				print("[CloudAuthenticationView] No account found, starting signup flow")
				pendingProvider = "Google"
				pendingOAuthTokens = oauthResult
				withAnimation {
					signupState = .noAccount
				}
			}
		} catch {
			print("[CloudAuthenticationView] Google sign-in failed: \(error)")
			errorMessage = error.localizedDescription
			showError = true
		}
	}

	private func signInWithApple() async {
		print("[CloudAuthenticationView] Starting Apple sign-in")
		isSigningIn = true
		defer {
			isSigningIn = false
			print("[CloudAuthenticationView] Apple sign-in completed, isSigningIn = false")
		}

		do {
			// First get OAuth tokens
			let oauthResult = try await accountManager.authenticateWithApple()

			// Check if account exists
			let accountExists = try await accountManager.checkAccountExists(
				provider: "apple",
				oauthTokens: oauthResult
			)

			if accountExists {
				// Existing user - sign in normally
				let user = try await accountManager.completeSignIn(
					provider: "apple",
					oauthTokens: oauthResult
				)
				print("[CloudAuthenticationView] Apple sign-in successful, existing user: \(user.displayName)")

				// Dismiss to show home screen
				await MainActor.run {
					isPresented = false
				}
			} else {
				// New user - show signup flow
				print("[CloudAuthenticationView] No account found, starting signup flow")
				pendingProvider = "Apple"
				pendingOAuthTokens = oauthResult
				withAnimation {
					signupState = .noAccount
				}
			}
		} catch {
			print("[CloudAuthenticationView] Apple sign-in failed: \(error)")
			errorMessage = error.localizedDescription
			showError = true
		}
	}

	private func createAccount() async {
		guard let provider = pendingProvider,
		      let tokens = pendingOAuthTokens else {
			print("[CloudAuthenticationView] Missing provider or tokens for account creation")
			return
		}

		isSigningIn = true
		defer {
			isSigningIn = false
		}

		do {
			// Create the account with terms acceptance
			let user = try await accountManager.createAccount(
				provider: provider.lowercased(),
				oauthTokens: tokens,
				termsAccepted: true
			)

			print("[CloudAuthenticationView] Account created successfully: \(user.displayName)")

			// Show welcome screen
			withAnimation {
				signupState = .welcome
			}
		} catch {
			print("[CloudAuthenticationView] Account creation failed: \(error)")
			errorMessage = error.localizedDescription
			showError = true

			// Return to sign-in on error
			pendingProvider = nil
			pendingOAuthTokens = nil
			withAnimation {
				signupState = .signIn
			}
		}
	}
}

#Preview {
	CloudAuthenticationView(isPresented: .constant(true))
}