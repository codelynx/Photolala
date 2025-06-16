import SwiftUI

struct AWSCredentialsView: View {
	@State private var accessKey = ""
	@State private var secretKey = ""
	@State private var showSecretKey = false
	@State private var isLoading = false
	@State private var errorMessage: String?
	@State private var showSuccessAlert = false
	@Environment(\.dismiss) private var dismiss
	
	var body: some View {
		Form {
			Section {
				VStack(alignment: .leading, spacing: 8) {
					Text("AWS S3 Backup Configuration")
						.font(.headline)
					Text("Enter your AWS credentials to enable cloud backup")
						.font(.caption)
						.foregroundColor(.secondary)
				}
				.padding(.vertical, 4)
			}
			
			Section("Credentials") {
				TextField("Access Key ID", text: $accessKey)
					.textFieldStyle(.roundedBorder)
					#if os(iOS)
					.autocapitalization(.none)
					#endif
					.disableAutocorrection(true)
				
				HStack {
					if showSecretKey {
						TextField("Secret Access Key", text: $secretKey)
							.textFieldStyle(.roundedBorder)
							#if os(iOS)
							.autocapitalization(.none)
							#endif
							.disableAutocorrection(true)
					} else {
						SecureField("Secret Access Key", text: $secretKey)
							.textFieldStyle(.roundedBorder)
					}
					
					Button(action: { showSecretKey.toggle() }) {
						Image(systemName: showSecretKey ? "eye.slash" : "eye")
							.foregroundColor(.secondary)
					}
					.buttonStyle(.plain)
				}
			}
			
			if let errorMessage = errorMessage {
				Section {
					HStack {
						Image(systemName: "exclamationmark.triangle")
							.foregroundColor(.red)
						Text(errorMessage)
							.font(.caption)
							.foregroundColor(.red)
					}
				}
			}
			
			Section {
				HStack {
					Button("Test Connection") {
						testConnection()
					}
					.disabled(accessKey.isEmpty || secretKey.isEmpty || isLoading)
					
					Spacer()
					
					Button("Save") {
						saveCredentials()
					}
					.disabled(accessKey.isEmpty || secretKey.isEmpty || isLoading)
					.buttonStyle(.borderedProminent)
				}
			}
			
			Section {
				VStack(alignment: .leading, spacing: 8) {
					Text("Security Note")
						.font(.caption.bold())
					Text("Your credentials are stored securely in the system Keychain and are never transmitted except to AWS.")
						.font(.caption)
						.foregroundColor(.secondary)
				}
			}
		}
		.formStyle(.grouped)
		.navigationTitle("AWS S3 Configuration")
		#if os(iOS)
		.navigationBarTitleDisplayMode(.inline)
		#endif
		.toolbar {
			ToolbarItem(placement: .cancellationAction) {
				Button("Cancel") {
					dismiss()
				}
			}
		}
		.overlay {
			if isLoading {
				ProgressView()
					.padding()
					.background(Color.secondary.opacity(0.1))
					.cornerRadius(10)
			}
		}
		.alert("Success", isPresented: $showSuccessAlert) {
			Button("OK") {
				dismiss()
			}
		} message: {
			Text("AWS credentials saved successfully!")
		}
		.onAppear {
			loadExistingCredentials()
		}
	}
	
	private func loadExistingCredentials() {
		if let credentials = try? KeychainManager.shared.loadAWSCredentials() {
			accessKey = credentials.accessKey
			secretKey = credentials.secretKey
		}
	}
	
	private func testConnection() {
		isLoading = true
		errorMessage = nil
		
		Task {
			do {
				// Try to create S3 service with provided credentials
				let service = try await S3BackupService(accessKey: accessKey, secretKey: secretKey)
				
				// Try to list buckets as a connection test
				_ = try await service.listUserPhotos(userId: "test")
				
				await MainActor.run {
					isLoading = false
					errorMessage = nil
					// Show success feedback
					#if os(iOS)
					let generator = UINotificationFeedbackGenerator()
					generator.notificationOccurred(.success)
					#endif
				}
			} catch {
				await MainActor.run {
					isLoading = false
					errorMessage = "Connection failed: \(error.localizedDescription)"
					#if os(iOS)
					let generator = UINotificationFeedbackGenerator()
					generator.notificationOccurred(.error)
					#endif
				}
			}
		}
	}
	
	private func saveCredentials() {
		isLoading = true
		errorMessage = nil
		
		Task {
			do {
				// Test credentials first
				_ = try await S3BackupService(accessKey: accessKey, secretKey: secretKey)
				
				// Save to Keychain
				try KeychainManager.shared.saveAWSCredentials(
					accessKey: accessKey,
					secretKey: secretKey
				)
				
				await MainActor.run {
					isLoading = false
					showSuccessAlert = true
				}
			} catch {
				await MainActor.run {
					isLoading = false
					errorMessage = "Failed to save: \(error.localizedDescription)"
				}
			}
		}
	}
}

#Preview {
	NavigationStack {
		AWSCredentialsView()
	}
}