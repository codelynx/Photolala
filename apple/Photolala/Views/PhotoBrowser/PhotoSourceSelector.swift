//
//  PhotoSourceSelector.swift
//  Photolala
//
//  Source selector menu for switching between photo sources
//

import SwiftUI

struct PhotoSourceSelector: View {
	@Binding var currentSource: PhotoSourceType
	let onSourceChanged: (PhotoSourceType) -> Void
	@StateObject private var accountManager = AccountManager.shared
	@State private var showAuthenticationView = false

	enum PhotoSourceType: String, CaseIterable {
		case local = "Local"
		case applePhotos = "Photos"
		case cloud = "Cloud"

		var icon: String {
			switch self {
			case .local: return "folder"
			case .applePhotos: return "photo.on.rectangle"
			case .cloud: return "icloud"
			}
		}

		var requiresAuth: Bool {
			self == .cloud
		}
	}

	var body: some View {
		Menu {
			ForEach(PhotoSourceType.allCases, id: \.self) { source in
				Button(action: {
					selectSource(source)
				}) {
					Label(source.rawValue, systemImage: source.icon)
				}
				.disabled(source.requiresAuth && !accountManager.isSignedIn)
			}

			if currentSource == .cloud && !accountManager.isSignedIn {
				Divider()
				Button(action: signIn) {
					Label("Sign In...", systemImage: "person.crop.circle.badge.plus")
				}
			}

			if accountManager.isSignedIn {
				Divider()
				Button(action: signOut) {
					Label("Sign Out", systemImage: "person.crop.circle.badge.minus")
				}
			}
		} label: {
			HStack(spacing: 4) {
				Image(systemName: currentSource.icon)
				Text(currentSource.rawValue)
				Image(systemName: "chevron.down")
					.font(.caption)
			}
		}
		.menuStyle(.borderlessButton)
		.fixedSize()
		.sheet(isPresented: $showAuthenticationView) {
			CloudAuthenticationView(isPresented: $showAuthenticationView)
		}
		.onChange(of: accountManager.isSignedIn) { _, newValue in
			// If just signed in and not already on cloud, switch to cloud
			if newValue && currentSource != .cloud {
				currentSource = .cloud
				onSourceChanged(.cloud)
			}
		}
	}

	private func selectSource(_ source: PhotoSourceType) {
		// Check if we need authentication
		if source.requiresAuth && !accountManager.isSignedIn {
			// Show sign in
			signIn()
		} else {
			currentSource = source
			onSourceChanged(source)
		}
	}

	private func signIn() {
		showAuthenticationView = true
	}

	private func signOut() {
		Task { @MainActor in
			await accountManager.signOut()
			// Switch to local source after sign out
			if currentSource == .cloud {
				currentSource = .local
				onSourceChanged(.local)
			}
		}
	}
}