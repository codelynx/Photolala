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
	@State private var showUnlinkConfirmation = false
	@State private var providerToUnlink: AuthProvider?
	
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
				VStack(spacing: 12) {
					// Primary provider
					ProviderRow(
						provider: user.primaryProvider,
						email: user.email,
						isPrimary: true,
						date: nil,
						onUnlink: nil
					)
					
					// Linked providers
					ForEach(user.linkedProviders) { link in
						ProviderRow(
							provider: link.provider,
							email: nil,
							isPrimary: false,
							date: link.linkedAt,
							onUnlink: { 
								providerToUnlink = link.provider
								showUnlinkConfirmation = true
							}
						)
					}
					
					// Add provider button
					if !availableProviders.isEmpty {
						Button(action: {
							showLinkProvider = true
						}) {
							HStack {
								Image(systemName: "plus.circle.fill")
									.font(.title3)
								Text("Link Another Sign-In Method")
									.fontWeight(.medium)
							}
							.frame(maxWidth: .infinity)
							.padding(.vertical, 12)
							.background(Color.accentColor.opacity(0.1))
							.foregroundColor(.accentColor)
							.clipShape(RoundedRectangle(cornerRadius: 10))
						}
						.buttonStyle(.plain)
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
		.confirmationDialog(
			"Unlink \(providerToUnlink?.displayName ?? "") Account?",
			isPresented: $showUnlinkConfirmation,
			titleVisibility: .visible
		) {
			Button("Unlink", role: .destructive) {
				if let provider = providerToUnlink {
					unlinkProvider(provider)
				}
			}
			Button("Cancel", role: .cancel) {}
		} message: {
			if let provider = providerToUnlink {
				Text("You'll no longer be able to sign in with your \(provider.displayName) account. You can always link it again later.")
			}
		}
	}
	
	private func linkProvider(_ provider: AuthProvider) {
		Task {
			isLinking = true
			defer { isLinking = false }
			
			do {
				guard let currentUser = user else { return }
				
				// Link the provider to the current account
				_ = try await identityManager.linkProvider(provider, to: currentUser)
				
				// Show success feedback
				print("[LinkedProvidersView] Successfully linked \(provider.displayName) account")
				
				// Show success alert
				await MainActor.run {
					errorMessage = "Successfully linked your \(provider.displayName) account! You can now sign in with either method."
					showError = true // Reusing error alert for success message
				}
			} catch {
				// Handle specific linking errors
				switch error {
				case AuthError.providerAlreadyLinked:
					errorMessage = "This sign-in method is already linked to your account"
				case AuthError.providerInUseByAnotherAccount:
					errorMessage = "This \(provider.displayName) account is already linked to a different Photolala account"
				case AuthError.userCancelled:
					// User cancelled - no error needed
					return
				default:
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
			VStack(spacing: 32) {
				// Header
				VStack(spacing: 12) {
					Image(systemName: "person.badge.plus")
						.font(.system(size: 60))
						.foregroundColor(.accentColor)
						.padding(.top, 40)
					
					Text("Link Sign-In Method")
						.font(.title)
						.fontWeight(.semibold)
					
					Text("Connect another way to sign in to your account")
						.font(.callout)
						.foregroundColor(.secondary)
						.multilineTextAlignment(.center)
						.padding(.horizontal)
				}
				
				// Provider options
				VStack(spacing: 16) {
					ForEach(availableProviders, id: \.self) { provider in
						Button(action: {
							onSelect(provider)
						}) {
							HStack(spacing: 16) {
								ZStack {
									Circle()
										.fill(provider == .apple ? Color.black : Color.white)
										.frame(width: 50, height: 50)
									
									Image(systemName: provider.iconName)
										.font(.title2)
										.foregroundColor(provider == .apple ? .white : .black)
								}
								
								VStack(alignment: .leading, spacing: 2) {
									Text("Link with \(provider.displayName)")
										.font(.headline)
									Text("Use your \(provider.displayName) account to sign in")
										.font(.caption)
										.foregroundColor(.secondary)
								}
								
								Spacer()
								
								Image(systemName: "chevron.right")
									.font(.caption)
									.foregroundColor(.secondary)
							}
							.padding()
							.background(Color(NSColor.controlBackgroundColor))
							.clipShape(RoundedRectangle(cornerRadius: 12))
						}
						.buttonStyle(.plain)
					}
				}
				.padding(.horizontal)
				
				Spacer()
			}
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") {
						dismiss()
					}
					.buttonStyle(.bordered)
				}
			}
		}
		#if os(macOS)
		.frame(width: 450, height: 500)
		#endif
	}
}

// MARK: - Provider Authentication Extension

// Note: Authentication is handled through IdentityManager

// MARK: - Provider Row Component

struct ProviderRow: View {
	let provider: AuthProvider
	let email: String?
	let isPrimary: Bool
	let date: Date?
	let onUnlink: (() -> Void)?
	
	var body: some View {
		HStack(spacing: 16) {
			// Provider icon
			ZStack {
				Circle()
					.fill(Color(NSColor.controlBackgroundColor))
					.frame(width: 44, height: 44)
				
				Image(systemName: provider.iconName)
					.font(.title3)
					.foregroundColor(.accentColor)
			}
			
			// Provider info
			VStack(alignment: .leading, spacing: 4) {
				HStack(spacing: 8) {
					Text(provider.displayName)
						.font(.body)
						.fontWeight(.medium)
					
					if isPrimary {
						StatusBadge(text: "Primary", color: .blue)
					}
				}
				
				if let email = email {
					Text(email)
						.font(.caption)
						.foregroundColor(.secondary)
				} else if let date = date {
					Text("Linked \(date.formatted(date: .abbreviated, time: .omitted))")
						.font(.caption)
						.foregroundColor(.secondary)
				}
			}
			
			Spacer()
			
			// Unlink button
			if let onUnlink = onUnlink, !isPrimary {
				Button("Unlink") {
					onUnlink()
				}
				.buttonStyle(.bordered)
				.controlSize(.small)
			}
		}
		.padding(.vertical, 8)
		.padding(.horizontal, 12)
		.background(Color(NSColor.controlBackgroundColor).opacity(0.5))
		.clipShape(RoundedRectangle(cornerRadius: 10))
	}
}

// MARK: - Preview

struct LinkedProvidersView_Previews: PreviewProvider {
	static var previews: some View {
		Form {
			LinkedProvidersView()
		}
		.environmentObject(IdentityManager.shared)
	}
}