//
//  TermsAcceptanceView.swift
//  Photolala
//
//  Terms of Service and Privacy Policy acceptance view
//

import SwiftUI

struct TermsAcceptanceView: View {
	@State private var hasAcceptedTerms = false
	@State private var selectedTab = 0
	let onAccept: () -> Void
	let onDecline: () -> Void

	var body: some View {
		VStack(spacing: 0) {
			// Header
			VStack(spacing: 12) {
				Image(systemName: "doc.text")
					.font(.system(size: 48))
					.foregroundStyle(.blue.gradient)

				Text("Terms & Conditions")
					.font(.largeTitle)
					.fontWeight(.bold)

				Text("Please review and accept our terms to continue")
					.font(.headline)
					.foregroundStyle(.secondary)
			}
			.padding(.vertical, 24)

			// Tab selector
			Picker("Document", selection: $selectedTab) {
				Text("Terms of Service").tag(0)
				Text("Privacy Policy").tag(1)
			}
			.pickerStyle(.segmented)
			.padding(.horizontal, 40)
			.padding(.bottom, 16)

			// Content
			ScrollView {
				Group {
					if selectedTab == 0 {
						TermsOfServiceContent()
					} else {
						PrivacyPolicyContent()
					}
				}
				.padding(.horizontal, 40)
				.padding(.vertical, 20)
			}
			.background(Color.secondary.opacity(0.05))
			.cornerRadius(12)
			.padding(.horizontal, 40)
			.frame(maxHeight: 300)

			// Acceptance checkbox
			HStack {
				Button(action: { hasAcceptedTerms.toggle() }) {
					HStack(spacing: 12) {
						Image(systemName: hasAcceptedTerms ? "checkmark.square.fill" : "square")
							.font(.title2)
							.foregroundStyle(hasAcceptedTerms ? .blue : .secondary)

						Text("I have read and accept the Terms of Service and Privacy Policy")
							.font(.body)
							.foregroundStyle(.primary)
							.multilineTextAlignment(.leading)

						Spacer()
					}
				}
				.buttonStyle(.plain)
			}
			.padding(.horizontal, 40)
			.padding(.vertical, 24)

			Spacer()

			// Action buttons
			VStack(spacing: 12) {
				Button(action: onAccept) {
					Text("Accept")
						.font(.headline)
						.frame(maxWidth: .infinity)
						.frame(height: 50)
						.background(hasAcceptedTerms ? Color.blue : Color.secondary.opacity(0.3))
						.foregroundColor(.white)
						.cornerRadius(12)
				}
				.buttonStyle(.plain)
				.disabled(!hasAcceptedTerms)

				Button(action: onDecline) {
					Text("No Thanks")
						.font(.headline)
						.frame(maxWidth: .infinity)
						.frame(height: 50)
						.background(Color.secondary.opacity(0.1))
						.foregroundColor(.primary)
						.cornerRadius(12)
				}
				.buttonStyle(.plain)
			}
			.padding(.horizontal, 40)
			.padding(.bottom, 40)
		}
		.frame(width: 600, height: 700)
	}
}

private struct TermsOfServiceContent: View {
	var body: some View {
		VStack(alignment: .leading, spacing: 20) {
			Section("1. Acceptance of Terms") {
				Text("By creating a Photolala account and using our services, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not create an account or use our services.")
			}

			Section("2. Use of Service") {
				Text("You may use Photolala to store, organize, and share your photos and videos. You agree to:")
				BulletPoint("Use the service only for lawful purposes")
				BulletPoint("Not upload content that violates others' rights")
				BulletPoint("Maintain the security of your account credentials")
				BulletPoint("Not attempt to circumvent any service limitations")
			}

			Section("3. Content Ownership") {
				Text("You retain all ownership rights to the photos and videos you upload. By uploading content, you grant Photolala a limited license to store, process, and display your content solely for the purpose of providing the service to you.")
			}

			Section("4. Privacy") {
				Text("Your privacy is important to us. Please review our Privacy Policy to understand how we collect, use, and protect your information.")
			}

			Section("5. Service Availability") {
				Text("While we strive to provide uninterrupted service, we do not guarantee that Photolala will be available at all times. We may perform maintenance or updates that temporarily affect service availability.")
			}

			Section("6. Account Termination") {
				Text("You may delete your account at any time through the app settings. We reserve the right to suspend or terminate accounts that violate these terms or engage in prohibited activities.")
			}

			Section("7. Limitation of Liability") {
				Text("Photolala is provided \"as is\" without warranties of any kind. We are not liable for any indirect, incidental, or consequential damages arising from your use of the service.")
			}

			Section("8. Changes to Terms") {
				Text("We may update these terms from time to time. We will notify you of significant changes, and continued use of the service constitutes acceptance of the updated terms.")
			}

			Section("9. Contact Information") {
				Text("If you have questions about these terms, please contact us at support@photolala.app")
			}

			Text("Last updated: \(Date.now.formatted(date: .long, time: .omitted))")
				.font(.caption)
				.foregroundStyle(.secondary)
				.padding(.top)
		}
	}
}

private struct PrivacyPolicyContent: View {
	var body: some View {
		VStack(alignment: .leading, spacing: 20) {
			Section("1. Information We Collect") {
				Text("We collect information you provide directly to us:")
				BulletPoint("Account information (email, name, profile photo)")
				BulletPoint("Photos and videos you upload")
				BulletPoint("Metadata associated with your content")
				BulletPoint("Usage data and preferences")
			}

			Section("2. How We Use Your Information") {
				Text("We use the information we collect to:")
				BulletPoint("Provide and maintain the Photolala service")
				BulletPoint("Process and store your photos securely")
				BulletPoint("Send service-related communications")
				BulletPoint("Improve and develop new features")
				BulletPoint("Protect against fraud and abuse")
			}

			Section("3. Information Sharing") {
				Text("We do not sell, trade, or rent your personal information. We may share information only in these circumstances:")
				BulletPoint("With your explicit consent")
				BulletPoint("To comply with legal obligations")
				BulletPoint("To protect rights and safety")
				BulletPoint("With service providers who assist our operations")
			}

			Section("4. Data Storage and Security") {
				Text("Your photos are encrypted both in transit and at rest. We use industry-standard security measures to protect your data, including:")
				BulletPoint("AES-256 encryption for stored data")
				BulletPoint("TLS encryption for data transmission")
				BulletPoint("Regular security audits and updates")
				BulletPoint("Limited access controls")
			}

			Section("5. Your Rights and Choices") {
				Text("You have the right to:")
				BulletPoint("Access your personal information")
				BulletPoint("Correct inaccurate data")
				BulletPoint("Delete your account and data")
				BulletPoint("Export your photos and data")
				BulletPoint("Opt-out of optional communications")
			}

			Section("6. Data Retention") {
				Text("We retain your data as long as your account is active. When you delete your account, we delete your data within 30 days, except where legal requirements mandate longer retention.")
			}

			Section("7. Children's Privacy") {
				Text("Photolala is not intended for children under 13. We do not knowingly collect information from children under 13.")
			}

			Section("8. International Data Transfers") {
				Text("Your data may be transferred to and processed in countries other than your own. We ensure appropriate safeguards are in place for such transfers.")
			}

			Section("9. Changes to Privacy Policy") {
				Text("We may update this policy from time to time. We will notify you of significant changes via the app or email.")
			}

			Section("10. Contact Us") {
				Text("For privacy-related questions, contact us at privacy@photolala.app")
			}

			Text("Last updated: \(Date.now.formatted(date: .long, time: .omitted))")
				.font(.caption)
				.foregroundStyle(.secondary)
				.padding(.top)
		}
	}
}

private struct Section<Content: View>: View {
	let title: String
	let content: Content

	init(_ title: String, @ViewBuilder content: () -> Content) {
		self.title = title
		self.content = content()
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text(title)
				.font(.headline)
				.fontWeight(.semibold)

			content
				.font(.body)
				.foregroundStyle(.secondary)
		}
	}
}

private struct BulletPoint: View {
	let text: String

	init(_ text: String) {
		self.text = text
	}

	var body: some View {
		HStack(alignment: .top, spacing: 8) {
			Text("•")
				.font(.body)
				.foregroundStyle(.secondary)

			Text(text)
				.font(.body)
				.foregroundStyle(.secondary)

			Spacer()
		}
		.padding(.leading, 16)
	}
}

#Preview {
	TermsAcceptanceView(
		onAccept: { print("Accepted") },
		onDecline: { print("Declined") }
	)
}