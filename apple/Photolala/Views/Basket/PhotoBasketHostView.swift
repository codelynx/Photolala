//
//  PhotoBasketHostView.swift
//  Photolala
//
//  Host view for displaying basket contents using the photo browser infrastructure
//

import SwiftUI

struct PhotoBasketHostView: View {
	@StateObject private var basket = PhotoBasket.shared
	@State private var environment: PhotoBrowserEnvironment
	@State private var showActionSheet = false
	@State private var selectedAction: BasketAction?
	@State private var showClearConfirmation = false
	@SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction

	init() {
		let provider = BasketPhotoProvider()
		let environment = PhotoBrowserEnvironment(source: provider)
		self._environment = State(initialValue: environment)
	}

	var body: some View {
		PhotoBrowserView(
			environment: environment,
			title: "Basket"
		)
		.navigationTitle("Photo Basket")
		.navigationSubtitle("\(basket.count) items")
		#if os(macOS)
		.navigationSubtitle(subtitle)
		#endif
		.toolbar {
			#if os(iOS)
			ToolbarItem(placement: .navigationBarLeading) {
				Button("Done") {
					dismiss()
				}
			}
			#endif

			// Action buttons
			ToolbarItemGroup(placement: .primaryAction) {
				if !basket.isEmpty {
					// Actions menu
					Menu {
						BasketActionsMenu(
							onAction: { action in
								selectedAction = action
								showActionSheet = true
							}
						)
					} label: {
						Label("Actions", systemImage: "ellipsis.circle")
					}

					// Clear basket
					Button(action: {
						showClearConfirmation = true
					}) {
						Label("Clear", systemImage: "trash")
					}
					.foregroundColor(.red)
				}
			}
		}
		.overlay {
			if basket.isEmpty {
				EmptyBasketView()
			}
		}
		.confirmationDialog(
			"Clear Basket?",
			isPresented: $showClearConfirmation,
			titleVisibility: .visible
		) {
			Button("Clear All Items", role: .destructive) {
				basket.clear()
			}
			Button("Cancel", role: .cancel) {}
		} message: {
			Text("Remove all \(basket.count) items from the basket?")
		}
		.sheet(item: $selectedAction) { action in
			BasketActionSheet(action: action, items: basket.items)
		}
	}

	private var subtitle: String {
		let stats = basket.statistics()
		var parts: [String] = ["\(basket.count) items"]

		if stats.totalSize > 0 {
			parts.append(stats.formattedTotalSize)
		}

		// Source breakdown if mixed
		let sources = basket.itemsBySource()
		if sources.count > 1 {
			let breakdown = sources.map { "\($0.value.count) \($0.key.displayName)" }
				.joined(separator: ", ")
			parts.append("(\(breakdown))")
		}

		return parts.joined(separator: " • ")
	}
}

// MARK: - Empty State

struct EmptyBasketView: View {
	var body: some View {
		VStack(spacing: 20) {
			Image(systemName: "basket")
				.font(.system(size: 60))
				.foregroundColor(.secondary)

			Text("Basket is Empty")
				.font(.title2)
				.fontWeight(.semibold)

			Text("Add photos from any source to perform batch operations")
				.font(.subheadline)
				.foregroundColor(.secondary)
				.multilineTextAlignment(.center)
				.frame(maxWidth: 300)

			VStack(alignment: .leading, spacing: 12) {
				Label("Press B to add selected photo", systemImage: "keyboard")
				Label("Press ⌘B to open basket", systemImage: "command")
				Label("Press ⇧⌘B to clear basket", systemImage: "clear")
			}
			.font(.caption)
			.foregroundColor(.secondary)
			.padding()
			.background(Color.secondary.opacity(0.1))
			.cornerRadius(8)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}
}

// MARK: - Basket Actions

public enum BasketAction: String, CaseIterable, Identifiable {
	case star = "Star"
	case unstar = "Unstar"
	case createAlbum = "Create Album"
	case addToAlbum = "Add to Album"
	case export = "Export"
	case archive = "Move to Archive"
	case retrieve = "Retrieve from Archive"

	public var id: String { rawValue }

	public var icon: String {
		switch self {
		case .star: return "star.fill"
		case .unstar: return "star.slash"
		case .createAlbum: return "folder.badge.plus"
		case .addToAlbum: return "folder.fill.badge.plus"
		case .export: return "square.and.arrow.up"
		case .archive: return "archivebox"
		case .retrieve: return "arrow.down.doc"
		}
	}

	var requiresConfirmation: Bool {
		switch self {
		case .archive, .retrieve: return true
		default: return false
		}
	}

	var tintColor: Color {
		switch self {
		case .star: return .yellow
		case .archive, .retrieve: return .orange
		default: return .accentColor
		}
	}
}

struct BasketActionsMenu: View {
	let onAction: (BasketAction) -> Void

	var body: some View {
		Section("Organization") {
			Button(action: { onAction(.star) }) {
				Label("Star All", systemImage: "star.fill")
			}

			Button(action: { onAction(.unstar) }) {
				Label("Unstar All", systemImage: "star.slash")
			}
		}

		Section("Albums") {
			Button(action: { onAction(.createAlbum) }) {
				Label("Create Album", systemImage: "folder.badge.plus")
			}

			Button(action: { onAction(.addToAlbum) }) {
				Label("Add to Album", systemImage: "folder.fill.badge.plus")
			}
		}

		Section("Export") {
			Button(action: { onAction(.export) }) {
				Label("Export...", systemImage: "square.and.arrow.up")
			}
		}

		Section("Archive") {
			Button(action: { onAction(.archive) }) {
				Label("Move to Archive", systemImage: "archivebox")
			}

			Button(action: { onAction(.retrieve) }) {
				Label("Retrieve from Archive", systemImage: "arrow.down.doc")
			}
		}
	}
}

// MARK: - Action Sheet

struct BasketActionSheet: View {
	let action: BasketAction
	let items: [BasketItem]
	@SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction
	@State private var isProcessing = false
	@State private var progress: Double = 0
	@State private var currentItem: String = ""
	@State private var error: Error?

	var body: some View {
		VStack(spacing: 20) {
			// Header
			HStack {
				Image(systemName: action.icon)
					.font(.largeTitle)
					.foregroundColor(action.tintColor)

				VStack(alignment: .leading) {
					Text(action.rawValue)
						.font(.title2)
						.fontWeight(.semibold)

					Text("\(items.count) items")
						.font(.subheadline)
						.foregroundColor(.secondary)
				}

				Spacer()

				Button("Cancel") {
					dismiss()
				}
				.buttonStyle(.bordered)
			}
			.padding()

			// Progress
			if isProcessing {
				VStack(spacing: 12) {
					ProgressView(value: progress)
						.progressViewStyle(.linear)

					Text(currentItem)
						.font(.caption)
						.foregroundColor(.secondary)
						.lineLimit(1)
				}
				.padding()
			}

			// Content based on action
			actionContent

			Spacer()

			// Action button
			Button(action: executeAction) {
				Label(
					isProcessing ? "Processing..." : "Execute",
					systemImage: isProcessing ? "clock" : action.icon
				)
			}
			.buttonStyle(.borderedProminent)
			.disabled(isProcessing)
			.controlSize(.large)
		}
		.padding()
		.frame(width: 500, height: 400)
		.alert("Error", isPresented: .constant(error != nil)) {
			Button("OK") {
				error = nil
			}
		} message: {
			Text(error?.localizedDescription ?? "Unknown error")
		}
	}

	@ViewBuilder
	private var actionContent: some View {
		switch action {
		case .star, .unstar:
			VStack {
				Text("This will \(action == .star ? "star" : "unstar") all items in the basket.")
					.multilineTextAlignment(.center)
			}

		case .createAlbum:
			VStack {
				TextField("Album Name", text: .constant(""))
					.textFieldStyle(.roundedBorder)
			}

		case .export:
			VStack {
				Text("Select export location...")
			}

		default:
			EmptyView()
		}
	}

	private func executeAction() {
		// TODO: Implement actual action execution via BasketActionService
		isProcessing = true

		Task {
			// Simulate processing
			for i in 0..<items.count {
				currentItem = items[i].displayName
				progress = Double(i + 1) / Double(items.count)

				try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
			}

			isProcessing = false
			dismiss()

			// Clear basket after successful action
			await PhotoBasket.shared.clear()
		}
	}
}
