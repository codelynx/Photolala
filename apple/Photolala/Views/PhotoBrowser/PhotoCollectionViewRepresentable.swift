//
//  PhotoCollectionViewRepresentable.swift
//  Photolala
//
//  SwiftUI bridge to native collection view
//

import SwiftUI

#if os(macOS)
struct PhotoCollectionViewRepresentable: NSViewControllerRepresentable {
	let photos: [PhotoBrowserItem]
	@Binding var selection: Set<PhotoBrowserItem>
	let environment: PhotoBrowserEnvironment
	let settings: PhotoBrowserSettings
	let onItemTapped: ((PhotoBrowserItem) -> Void)?

	func makeNSViewController(context: Context) -> PhotoCollectionViewController {
		let controller = PhotoCollectionViewController(environment: environment, settings: settings)
		controller.onItemTapped = onItemTapped
		controller.onSelectionChanged = { newSelection in
			self.selection = newSelection
		}
		return controller
	}

	func updateNSViewController(_ controller: PhotoCollectionViewController, context: Context) {
		// Update environment if source changed
		if controller.environment.source !== environment.source {
			controller.environment = environment
		}

		// Update photos if changed
		if controller.photos != photos {
			controller.photos = photos
		}

		// Update selection if changed
		if controller.selection != selection {
			controller.selection = selection
		}

		// Update item size if settings changed
		controller.updateItemSize()
	}

	typealias NSViewControllerType = PhotoCollectionViewController
}
#else
struct PhotoCollectionViewRepresentable: UIViewControllerRepresentable {
	let photos: [PhotoBrowserItem]
	@Binding var selection: Set<PhotoBrowserItem>
	let environment: PhotoBrowserEnvironment
	let settings: PhotoBrowserSettings
	let onItemTapped: ((PhotoBrowserItem) -> Void)?

	func makeUIViewController(context: Context) -> PhotoCollectionViewController {
		let controller = PhotoCollectionViewController(environment: environment, settings: settings)
		controller.onItemTapped = onItemTapped
		controller.onSelectionChanged = { newSelection in
			self.selection = newSelection
		}
		return controller
	}

	func updateUIViewController(_ controller: PhotoCollectionViewController, context: Context) {
		// Update environment if source changed
		if controller.environment.source !== environment.source {
			controller.environment = environment
		}

		// Update photos if changed
		if controller.photos != photos {
			controller.photos = photos
		}

		// Update selection if changed
		if controller.selection != selection {
			controller.selection = selection
		}

		// Update item size if settings changed
		controller.updateItemSize()
	}

	typealias UIViewControllerType = PhotoCollectionViewController
}
#endif