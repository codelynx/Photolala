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
				TextField("Access Key ID", text: self.$accessKey)
					.textFieldStyle(.roundedBorder)
				#if os(iOS)
					.autocapitalization(.none)
				#endif
					.disableAutocorrection(true)

				HStack {
					if self.showSecretKey {
						TextField("Secret Access Key", text: self.$secretKey)
							.textFieldStyle(.roundedBorder)
						#if os(iOS)
							.autocapitalization(.none)
						#endif
							.disableAutocorrection(true)
					} else {
						SecureField("Secret Access Key", text: self.$secretKey)
							.textFieldStyle(.roundedBorder)
					}

					Button(action: { self.showSecretKey.toggle() }) {
						Image(systemName: self.showSecretKey ? "eye.slash" : "eye")
							.foregroundColor(.secondary)
					}
					.buttonStyle(.plain)
				}
			}

			if let errorMessage {
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
						self.testConnection()
					}
					.disabled(self.accessKey.isEmpty || self.secretKey.isEmpty || self.isLoading)

					Spacer()

					Button("Save") {
						self.saveCredentials()
					}
					.disabled(self.accessKey.isEmpty || self.secretKey.isEmpty || self.isLoading)
					.buttonStyle(.borderedProminent)
				}
			}

			Section {
				VStack(alignment: .leading, spacing: 8) {
					Text("Security Note")
						.font(.caption.bold())
					Text(
						"Your credentials are stored securely in the system Keychain and are never transmitted except to AWS."
					)
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
						self.dismiss()
					}
				}
			}
			.overlay {
				if self.isLoading {
					ProgressView()
						.padding()
						.background(Color.secondary.opacity(0.1))
						.cornerRadius(10)
				}
			}
			.alert("Success", isPresented: self.$showSuccessAlert) {
				Button("OK") {
					self.dismiss()
				}
			} message: {
				Text("AWS credentials saved successfully!")
			}
			.onAppear {
				self.loadExistingCredentials()
			}
	}

	private func loadExistingCredentials() {
		if let credentials = try? KeychainManager.shared.loadAWSCredentials() {
			self.accessKey = credentials.accessKey
			self.secretKey = credentials.secretKey
		}
	}

	private func testConnection() {
		self.isLoading = true
		self.errorMessage = nil

		Task {
			do {
				// Try to create S3 service with provided credentials
				let service = try await S3BackupService(accessKey: accessKey, secretKey: secretKey)

				// Try to list buckets as a connection test
				_ = try await service.listUserPhotos(userId: "test")

				await MainActor.run {
					self.isLoading = false
					self.errorMessage = nil
					// Show success feedback
					#if os(iOS)
						let generator = UINotificationFeedbackGenerator()
						generator.notificationOccurred(.success)
					#endif
				}
			} catch {
				await MainActor.run {
					self.isLoading = false
					self.errorMessage = "Connection failed: \(error.localizedDescription)"
					#if os(iOS)
						let generator = UINotificationFeedbackGenerator()
						generator.notificationOccurred(.error)
					#endif
				}
			}
		}
	}

	private func saveCredentials() {
		self.isLoading = true
		self.errorMessage = nil

		Task {
			do {
				// Test credentials first
				_ = try await S3BackupService(accessKey: self.accessKey, secretKey: self.secretKey)

				// Save to Keychain
				try KeychainManager.shared.saveAWSCredentials(
					accessKey: self.accessKey,
					secretKey: self.secretKey
				)

				await MainActor.run {
					self.isLoading = false
					self.showSuccessAlert = true
				}
			} catch {
				await MainActor.run {
					self.isLoading = false
					self.errorMessage = "Failed to save: \(error.localizedDescription)"
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
