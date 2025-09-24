//
//  BasketBadgeView.swift
//  Photolala
//
//  Toolbar badge showing basket count with quick access
//

import SwiftUI

struct BasketBadgeView: View {
	@StateObject private var basket = PhotoBasket.shared
	@State private var showBasketView = false
	@State private var isAnimating = false

	var body: some View {
		Button(action: {
			showBasketView = true
		}) {
			HStack(spacing: 4) {
				Image(systemName: basket.isEmpty ? "basket" : "basket.fill")
					.foregroundColor(basket.isEmpty ? .secondary : .accentColor)
					.scaleEffect(isAnimating ? 1.2 : 1.0)

				if basket.count > 0 {
					Text("\(basket.count)")
						.font(.caption)
						.fontWeight(.medium)
						.padding(.horizontal, 6)
						.padding(.vertical, 2)
						.background(
							Capsule()
								.fill(Color.accentColor)
						)
						.foregroundColor(.white)
						.transition(.scale.combined(with: .opacity))
				}
			}
		}
		.buttonStyle(.plain)
		.disabled(basket.isEmpty)
		.help("Photo Basket (\(basket.count) items) - ⌘B")
		.keyboardShortcut("b", modifiers: .command)
		.sheet(isPresented: $showBasketView) {
			NavigationStack {
				PhotoBasketHostView()
			}
			#if os(macOS)
			.frame(minWidth: 900, minHeight: 600)
			#endif
		}
		.onChange(of: basket.count) { oldCount, newCount in
			// Animate when items are added
			if newCount > oldCount {
				withAnimation(.spring(duration: 0.3)) {
					isAnimating = true
				}
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
					withAnimation(.spring(duration: 0.3)) {
						isAnimating = false
					}
				}
			}
		}
	}
}

// MARK: - Quick Action Menu

struct BasketQuickActionsMenu: View {
	@StateObject private var basket = PhotoBasket.shared

	var body: some View {
		Menu {
			Button(action: {
				// Open basket view
			}) {
				Label("Open Basket", systemImage: "basket.fill")
			}
			.keyboardShortcut("b", modifiers: .command)

			Divider()

			if !basket.isEmpty {
				Button(action: {
					basket.clear()
				}) {
					Label("Clear Basket", systemImage: "trash")
				}
				.keyboardShortcut("b", modifiers: [.command, .shift])

				Divider()

				// Quick stats
				Section {
					Label("\(basket.count) items", systemImage: "photo.stack")
						.foregroundColor(.secondary)

					if basket.totalFileSize > 0 {
						Label(
							ByteCountFormatter.string(fromByteCount: basket.totalFileSize, countStyle: .file),
							systemImage: "externaldrive"
						)
						.foregroundColor(.secondary)
					}
				}
			}
		} label: {
			BasketBadgeView()
		}
		.menuStyle(.borderlessButton)
	}
}

// MARK: - Basket Add Button (for photo cells)

struct BasketAddButton: View {
	let item: PhotoBrowserItem
	let sourceType: PhotoSourceType
	let sourceIdentifier: String?
	let sourceURL: URL?

	@StateObject private var basket = PhotoBasket.shared
	@State private var isAnimating = false

	private var isInBasket: Bool {
		basket.contains(item.id)
	}

	init(
		item: PhotoBrowserItem,
		sourceType: PhotoSourceType,
		sourceIdentifier: String? = nil,
		sourceURL: URL? = nil
	) {
		self.item = item
		self.sourceType = sourceType
		self.sourceIdentifier = sourceIdentifier
		self.sourceURL = sourceURL
	}

	var body: some View {
		Button(action: toggleBasket) {
			ZStack {
				Circle()
					.fill(Color.black.opacity(0.5))
					.frame(width: 28, height: 28)

				Image(systemName: isInBasket ? "checkmark.circle.fill" : "plus.circle")
					.font(.system(size: 16, weight: .medium))
					.foregroundColor(isInBasket ? .green : .white)
					.scaleEffect(isAnimating ? 1.3 : 1.0)
			}
		}
		.buttonStyle(.plain)
		.help(isInBasket ? "Remove from basket" : "Add to basket (B)")
		.transition(.scale.combined(with: .opacity))
	}

	private func toggleBasket() {
		withAnimation(.spring(duration: 0.3)) {
			isAnimating = true
		}

		basket.toggle(
			item,
			sourceType: sourceType,
			sourceIdentifier: sourceIdentifier,
			url: sourceURL
		)

		DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
			withAnimation(.spring(duration: 0.3)) {
				isAnimating = false
			}
		}

		// Haptic feedback on iOS
		#if os(iOS)
		let impact = UIImpactFeedbackGenerator(style: .light)
		impact.impactOccurred()
		#endif
	}
}

// MARK: - Preview

struct BasketBadgeView_Previews: PreviewProvider {
	static var previews: some View {
		VStack(spacing: 20) {
			BasketBadgeView()

			BasketQuickActionsMenu()

			HStack {
				BasketAddButton(
					item: PhotoBrowserItem(id: "1", displayName: "Test.jpg"),
					sourceType: .local
				)
			}
			.padding()
		}
		.padding()
		.frame(width: 400, height: 300)
	}
}