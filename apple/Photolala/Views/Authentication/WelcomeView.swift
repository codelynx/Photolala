//
//  WelcomeView.swift
//  Photolala
//
//  Welcome screen shown after successful account creation
//

import SwiftUI

struct WelcomeView: View {
	let userName: String
	let onGetStarted: () -> Void
	@State private var showConfetti = false
	@State private var animateFeatures = false

	var body: some View {
		ZStack {
			// Background gradient
			LinearGradient(
				colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
				startPoint: .topLeading,
				endPoint: .bottomTrailing
			)
			.ignoresSafeArea()

			VStack(spacing: 32) {
				Spacer()

				// Logo with animation
				ZStack {
					Circle()
						.fill(Color.blue.gradient)
						.frame(width: 120, height: 120)
						.blur(radius: showConfetti ? 20 : 0)
						.scaleEffect(showConfetti ? 1.2 : 0.8)
						.animation(.easeOut(duration: 0.6), value: showConfetti)

					Image(systemName: "photo.stack.fill")
						.font(.system(size: 60))
						.foregroundStyle(.white)
						.scaleEffect(showConfetti ? 1 : 0)
						.animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1), value: showConfetti)
				}

				// Welcome message
				VStack(spacing: 12) {
					Text("Welcome to Photolala!")
						.font(.largeTitle)
						.fontWeight(.bold)
						.opacity(showConfetti ? 1 : 0)
						.animation(.easeIn(duration: 0.4).delay(0.3), value: showConfetti)

					Text("Hi \(userName), your account is ready!")
						.font(.title2)
						.foregroundStyle(.secondary)
						.opacity(showConfetti ? 1 : 0)
						.animation(.easeIn(duration: 0.4).delay(0.4), value: showConfetti)
				}

				// Feature highlights
				VStack(spacing: 16) {
					FeatureHighlight(
						icon: "icloud.and.arrow.up",
						title: "Automatic Backup",
						description: "Your photos are safely backed up to the cloud",
						color: .blue,
						isAnimated: animateFeatures,
						delay: 0.5
					)

					FeatureHighlight(
						icon: "sparkles",
						title: "Smart Organization",
						description: "AI-powered photo organization and search",
						color: .purple,
						isAnimated: animateFeatures,
						delay: 0.6
					)

					FeatureHighlight(
						icon: "lock.shield.fill",
						title: "Private & Secure",
						description: "End-to-end encryption keeps your memories safe",
						color: .green,
						isAnimated: animateFeatures,
						delay: 0.7
					)

					FeatureHighlight(
						icon: "devices",
						title: "Access Anywhere",
						description: "View your photos from any device",
						color: .orange,
						isAnimated: animateFeatures,
						delay: 0.8
					)
				}
				.padding(.horizontal, 40)

				Spacer()

				// Get Started button
				Button(action: onGetStarted) {
					HStack {
						Text("Get Started")
							.font(.headline)

						Image(systemName: "arrow.right")
							.font(.headline)
					}
					.frame(maxWidth: .infinity)
					.frame(height: 56)
					.background(Color.blue.gradient)
					.foregroundColor(.white)
					.cornerRadius(16)
					.shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
				}
				.buttonStyle(.plain)
				.padding(.horizontal, 40)
				.scaleEffect(animateFeatures ? 1 : 0.9)
				.opacity(animateFeatures ? 1 : 0)
				.animation(.spring(response: 0.5, dampingFraction: 0.7).delay(1), value: animateFeatures)

				Spacer()
			}
			.frame(width: 500, height: 700)

			// Confetti effect (simplified)
			if showConfetti {
				ConfettiView()
					.allowsHitTesting(false)
			}
		}
		.onAppear {
			withAnimation {
				showConfetti = true
			}
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
				animateFeatures = true
			}
		}
	}
}

private struct FeatureHighlight: View {
	let icon: String
	let title: String
	let description: String
	let color: Color
	let isAnimated: Bool
	let delay: Double

	var body: some View {
		HStack(spacing: 16) {
			Image(systemName: icon)
				.font(.title2)
				.foregroundStyle(color)
				.frame(width: 40, height: 40)
				.background(color.opacity(0.1))
				.cornerRadius(8)

			VStack(alignment: .leading, spacing: 4) {
				Text(title)
					.font(.headline)

				Text(description)
					.font(.caption)
					.foregroundStyle(.secondary)
			}

			Spacer()
		}
		.padding(12)
		.background(Color.primary.opacity(0.03))
		.cornerRadius(12)
		.offset(x: isAnimated ? 0 : -50)
		.opacity(isAnimated ? 1 : 0)
		.animation(.spring(response: 0.5, dampingFraction: 0.7).delay(delay), value: isAnimated)
	}
}

private struct ConfettiView: View {
	@State private var confettiPieces: [ConfettiPiece] = []

	var body: some View {
		GeometryReader { geometry in
			ZStack {
				ForEach(confettiPieces) { piece in
					Rectangle()
						.fill(piece.color)
						.frame(width: piece.size.width, height: piece.size.height)
						.position(piece.position)
						.rotationEffect(piece.rotation)
						.opacity(piece.opacity)
						.animation(
							.linear(duration: piece.duration),
							value: piece.position
						)
				}
			}
			.onAppear {
				createConfetti(in: geometry.size)
			}
		}
	}

	private func createConfetti(in size: CGSize) {
		for _ in 0..<50 {
			let piece = ConfettiPiece(
				position: CGPoint(
					x: CGFloat.random(in: 0...size.width),
					y: -20
				),
				color: [.blue, .purple, .green, .orange, .pink, .yellow].randomElement()!,
				size: CGSize(
					width: CGFloat.random(in: 4...8),
					height: CGFloat.random(in: 8...12)
				),
				rotation: Angle(degrees: Double.random(in: 0...360)),
				duration: Double.random(in: 2...4),
				opacity: Double.random(in: 0.6...1)
			)
			confettiPieces.append(piece)
		}

		// Animate falling
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
			for index in confettiPieces.indices {
				confettiPieces[index].position.y = size.height + 50
				confettiPieces[index].rotation = Angle(degrees: Double.random(in: 360...720))
			}
		}

		// Clean up
		DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
			confettiPieces.removeAll()
		}
	}
}

private struct ConfettiPiece: Identifiable {
	let id = UUID()
	var position: CGPoint
	let color: Color
	let size: CGSize
	var rotation: Angle
	let duration: Double
	let opacity: Double
}

#Preview {
	WelcomeView(
		userName: "John",
		onGetStarted: { print("Get started") }
	)
}