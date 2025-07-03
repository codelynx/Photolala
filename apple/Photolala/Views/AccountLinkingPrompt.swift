//
//  AccountLinkingPrompt.swift
//  Photolala
//
//  Created by Claude on 7/3/25.
//

import SwiftUI

struct AccountLinkingPrompt: View {
	let existingUser: PhotolalaUser
	let newCredential: AuthCredential
	let onLink: () -> Void
	let onCreateNew: () -> Void
	@Environment(\.dismiss) private var dismiss
	
	var body: some View {
		VStack(spacing: 24) {
			// Icon
			Image(systemName: "link.circle.fill")
				.font(.system(size: 60))
				.foregroundColor(.accentColor)
				.symbolRenderingMode(.hierarchical)
			
			// Title
			Text("Account Found")
				.font(.title)
				.fontWeight(.semibold)
			
			// Message
			VStack(spacing: 8) {
				Text("An account already exists with")
				Text(newCredential.email ?? "this email")
					.fontWeight(.medium)
			}
			.multilineTextAlignment(.center)
			.foregroundColor(.secondary)
			
			// Account comparison
			VStack(alignment: .leading, spacing: 16) {
				// Existing account
				HStack(spacing: 12) {
					Image(systemName: existingUser.primaryProvider.iconName)
						.font(.title2)
						.frame(width: 32)
					
					VStack(alignment: .leading, spacing: 2) {
						Text("Existing account")
							.font(.caption)
							.foregroundColor(.secondary)
						Text("Signed in with \(existingUser.primaryProvider.displayName)")
							.fontWeight(.medium)
					}
					
					Spacer()
				}
				.padding()
				.background(Color.gray.opacity(0.1))
				.cornerRadius(10)
				
				// New sign-in attempt
				HStack(spacing: 12) {
					Image(systemName: newCredential.provider.iconName)
						.font(.title2)
						.frame(width: 32)
					
					VStack(alignment: .leading, spacing: 2) {
						Text("You're trying to")
							.font(.caption)
							.foregroundColor(.secondary)
						Text("Sign in with \(newCredential.provider.displayName)")
							.fontWeight(.medium)
					}
					
					Spacer()
				}
				.padding()
				.background(Color.accentColor.opacity(0.1))
				.cornerRadius(10)
			}
			.padding(.vertical)
			
			// Options
			Text("Would you like to link these sign-in methods?")
				.multilineTextAlignment(.center)
			
			// Action buttons
			VStack(spacing: 12) {
				Button(action: onLink) {
					Label("Link to Existing Account", systemImage: "link")
						.frame(maxWidth: .infinity)
				}
				.buttonStyle(.borderedProminent)
				.controlSize(.large)
				
				Button(action: onCreateNew) {
					Text("Create Separate Account")
						.frame(maxWidth: .infinity)
				}
				.buttonStyle(.bordered)
				.controlSize(.large)
				
				Button("Cancel") {
					dismiss()
				}
				.buttonStyle(.plain)
				.foregroundColor(.secondary)
			}
		}
		.padding()
		.frame(maxWidth: 500)
		#if os(macOS)
		.frame(minWidth: 400, minHeight: 500)
		#endif
	}
}

// MARK: - Provider Extensions
// Note: AuthProvider extensions moved to AuthProvider.swift to avoid duplication

// MARK: - Preview

struct AccountLinkingPrompt_Previews: PreviewProvider {
	static var previews: some View {
		AccountLinkingPrompt(
			existingUser: PhotolalaUser(
				serviceUserID: "123",
				provider: .apple,
				providerID: "apple123",
				email: "user@example.com",
				fullName: "Test User",
				photoURL: nil
			),
			newCredential: AuthCredential(
				provider: .google,
				providerID: "google123",
				email: "user@example.com",
				fullName: "Test User",
				photoURL: nil,
				idToken: nil,
				accessToken: nil
			),
			onLink: {},
			onCreateNew: {}
		)
	}
}