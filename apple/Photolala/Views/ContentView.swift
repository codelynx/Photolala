//
//  ContentView.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/09/20.
//

import SwiftUI

struct ContentView: View {
	@State private var model = Model()

	var body: some View {
		VStack(spacing: 20) {
			Image(systemName: model.iconName)
				.imageScale(.large)
				.foregroundStyle(.tint)
			Text(model.greeting)

			if let user = model.currentUser {
				Text("Signed in as: \(user.email ?? "Unknown")")
					.foregroundStyle(.secondary)

				Button("Sign Out") {
					Task {
						await model.signOut()
					}
				}
				.buttonStyle(.borderedProminent)
			} else {
				HStack(spacing: 20) {
					Button("Sign in with Apple") {
						Task {
							await model.signInWithApple()
						}
					}
					.buttonStyle(.borderedProminent)

					Button("Sign in with Google") {
						Task {
							await model.signInWithGoogle()
						}
					}
					.buttonStyle(.borderedProminent)
				}
			}

			if let errorMessage = model.errorMessage {
				Text(errorMessage)
					.foregroundStyle(.red)
					.font(.caption)
			}
		}
		.padding()
		.task {
			await model.checkSignInStatus()
		}
	}
}

// MARK: - View Model
extension ContentView {
	@Observable
	final class Model {
		var greeting = "Hello, Photolala!"
		var iconName = "photo.stack"
		var currentUser: PhotolalaUser?
		var errorMessage: String?

		@MainActor
		func checkSignInStatus() async {
			currentUser = AccountManager.shared.getCurrentUser()
			if currentUser != nil {
				greeting = "Welcome back!"
			}
		}

		@MainActor
		func signInWithApple() async {
			errorMessage = nil
			do {
				let user = try await AccountManager.shared.signInWithApple()
				currentUser = user
				greeting = "Welcome, \(user.displayName ?? "User")!"
			} catch {
				errorMessage = "Apple Sign-In failed: \(error.localizedDescription)"
			}
		}

		@MainActor
		func signInWithGoogle() async {
			print("ContentView: Starting Google Sign-In")
			errorMessage = nil
			do {
				let user = try await AccountManager.shared.signInWithGoogle()
				currentUser = user
				greeting = "Welcome, \(user.displayName ?? "User")!"
				print("ContentView: Sign-in successful for \(user.email ?? "unknown")")
			} catch {
				errorMessage = "Google Sign-In failed: \(error.localizedDescription)"
				print("ContentView: Sign-in failed - \(error)")
			}
		}

		@MainActor
		func signOut() async {
			await AccountManager.shared.signOut()
			currentUser = nil
			greeting = "Hello, Photolala!"
			errorMessage = nil
		}
	}
}

#Preview {
	ContentView()
}
