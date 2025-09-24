//
//  CloudAuthenticationView.swift
//  Photolala
//
//  Sign-in view for cloud authentication
//

import SwiftUI
import GoogleSignInSwift

struct CloudAuthenticationView: View {
	@Binding var isPresented: Bool
	@StateObject private var accountManager = AccountManager.shared

	@State private var isSigningIn = false
	@State private var errorMessage: String?
	@State private var showError = false

	var body: some View {
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
			let user = try await accountManager.signInWithGoogle()
			print("[CloudAuthenticationView] Google sign-in successful, user: \(user.displayName)")
			// Ensure the view dismisses after successful sign-in
			await MainActor.run {
				if accountManager.isSignedIn {
					print("[CloudAuthenticationView] Dismissing after successful sign-in")
					isPresented = false
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
			let user = try await accountManager.signInWithApple()
			print("[CloudAuthenticationView] Apple sign-in successful, user: \(user.displayName)")
			// Ensure the view dismisses after successful sign-in
			await MainActor.run {
				if accountManager.isSignedIn {
					print("[CloudAuthenticationView] Dismissing after successful sign-in")
					isPresented = false
				}
			}
		} catch {
			print("[CloudAuthenticationView] Apple sign-in failed: \(error)")
			errorMessage = error.localizedDescription
			showError = true
		}
	}
}

#Preview {
	CloudAuthenticationView(isPresented: .constant(true))
}