//
//  LinkedProvidersView.swift
//  Photolala
//
//  Created by Claude on 7/3/25.
//

import SwiftUI

struct LinkedProvidersView: View {
	@EnvironmentObject private var identityManager: IdentityManager
	@State private var showLinkProvider = false
	@State private var selectedProvider: AuthProvider?
	@State private var isLinking = false
	@State private var showError = false
	@State private var errorMessage = ""
	
	private var user: PhotolalaUser? {
		identityManager.currentUser
	}
	
	private var availableProviders: [AuthProvider] {
		guard let user = user else { return [] }
		
		return AuthProvider.allCases.filter { provider in
			// Can't link if it's the primary provider
			if provider == user.primaryProvider {
				return false
			}
			
			// Can't link if already linked
			if user.linkedProviders.contains(where: { $0.provider == provider }) {
				return false
			}
			
			return true
		}
	}
	
	var body: some View {
		Group {
			if let user = user {
				Section("Sign-In Methods") {
					// Primary provider
					HStack {
						Image(systemName: user.primaryProvider.iconName)
							.frame(width: 24)
							.foregroundColor(.accentColor)
						
						VStack(alignment: .leading, spacing: 2) {
							Text(user.primaryProvider.displayName)
								.font(.body)
							if let email = user.email {
								Text(email)
									.font(.caption)
									.foregroundColor(.secondary)
							}
						}
						
						Spacer()
						
						Text("Primary")
							.font(.caption)
							.foregroundColor(.secondary)
							.padding(.horizontal, 8)
							.padding(.vertical, 4)
							.background(Color.gray.opacity(0.2))
							.cornerRadius(4)
					}
					.padding(.vertical, 4)
					
					// Linked providers
					ForEach(user.linkedProviders) { link in
						HStack {
							Image(systemName: link.provider.iconName)
								.frame(width: 24)
								.foregroundColor(.accentColor)
							
							VStack(alignment: .leading, spacing: 2) {
								Text(link.provider.displayName)
									.font(.body)
								Text("Linked \(link.linkedAt.formatted(date: .abbreviated, time: .omitted))")
									.font(.caption)
									.foregroundColor(.secondary)
							}
							
							Spacer()
							
							Button("Unlink") {
								unlinkProvider(link.provider)
							}
							.buttonStyle(.bordered)
							.controlSize(.small)
						}
						.padding(.vertical, 4)
					}
					
					// Add provider button
					if !availableProviders.isEmpty {
						Button(action: {
							showLinkProvider = true
						}) {
							Label("Link Another Sign-In Method", systemImage: "plus.circle")
						}
						.disabled(isLinking)
					}
				}
			}
		}
		.sheet(isPresented: $showLinkProvider) {
			LinkProviderSheet(
				availableProviders: availableProviders,
				onSelect: { provider in
					selectedProvider = provider
					showLinkProvider = false
					linkProvider(provider)
				}
			)
		}
		.alert("Error", isPresented: $showError) {
			Button("OK") {
				showError = false
			}
		} message: {
			Text(errorMessage)
		}
	}
	
	private func linkProvider(_ provider: AuthProvider) {
		Task {
			isLinking = true
			defer { isLinking = false }
			
			do {
				// The sign-in process will automatically handle linking if the email matches
				_ = try await identityManager.signIn(with: provider)
			} catch {
				// If it's an account exists error, that means the provider is already linked elsewhere
				if case AuthError.accountAlreadyExists = error {
					errorMessage = "This \(provider.displayName) account is already linked to another Photolala account"
				} else {
					errorMessage = error.localizedDescription
				}
				showError = true
			}
		}
	}
	
	private func unlinkProvider(_ provider: AuthProvider) {
		Task {
			do {
				if let user = user {
					_ = try await identityManager.unlinkProvider(provider, from: user)
				}
			} catch {
				errorMessage = error.localizedDescription
				showError = true
			}
		}
	}
}

// MARK: - Link Provider Sheet

struct LinkProviderSheet: View {
	let availableProviders: [AuthProvider]
	let onSelect: (AuthProvider) -> Void
	@Environment(\.dismiss) private var dismiss
	
	var body: some View {
		NavigationStack {
			VStack(spacing: 24) {
				Text("Link Sign-In Method")
					.font(.title2)
					.fontWeight(.semibold)
					.padding(.top)
				
				Text("Link another way to sign in to your account")
					.foregroundColor(.secondary)
					.multilineTextAlignment(.center)
				
				VStack(spacing: 12) {
					ForEach(availableProviders, id: \.self) { provider in
						Button(action: {
							onSelect(provider)
						}) {
							HStack {
								Image(systemName: provider.iconName)
									.font(.title3)
								Text("Link \(provider.displayName)")
									.fontWeight(.medium)
							}
							.frame(maxWidth: .infinity)
							.padding()
							.background(Color.gray.opacity(0.1))
							.cornerRadius(10)
						}
						.buttonStyle(.plain)
					}
				}
				.padding()
				
				Spacer()
			}
			.padding()
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") {
						dismiss()
					}
				}
			}
		}
		#if os(macOS)
		.frame(width: 400, height: 300)
		#endif
	}
}

// MARK: - Provider Authentication Extension

// Note: Authentication is handled through IdentityManager

// MARK: - Preview

struct LinkedProvidersView_Previews: PreviewProvider {
	static var previews: some View {
		Form {
			LinkedProvidersView()
		}
		.environmentObject(IdentityManager.shared)
	}
}