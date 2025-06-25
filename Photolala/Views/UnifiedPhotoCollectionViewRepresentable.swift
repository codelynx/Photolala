//
//  UnifiedPhotoCollectionViewRepresentable.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/06/19.
//

import SwiftUI

// MARK: - UnifiedPhotoCollectionView Representable

struct UnifiedPhotoCollectionViewRepresentable: XViewControllerRepresentable {
	let photoProvider: any PhotoProvider
	@Binding var settings: ThumbnailDisplaySettings
	let onSelectPhoto: ((any PhotoItem, [any PhotoItem]) -> Void)?
	let onSelectionChanged: (([any PhotoItem]) -> Void)?
	@Binding var scrollToSelection: Bool
	
	#if os(macOS)
	func makeNSViewController(context: Context) -> UnifiedPhotoCollectionViewController {
		let controller = UnifiedPhotoCollectionViewController(photoProvider: photoProvider)
		controller.settings = settings
		controller.delegate = context.coordinator
		return controller
	}
	
	func updateNSViewController(_ controller: UnifiedPhotoCollectionViewController, context: Context) {
		controller.settings = settings
		
		// Handle scroll to selection
		if scrollToSelection {
			controller.scrollToFirstSelectedItem(animated: true)
			// Reset the trigger
			DispatchQueue.main.async {
				scrollToSelection = false
			}
		}
	}
	#else
	func makeUIViewController(context: Context) -> UnifiedPhotoCollectionViewController {
		let controller = UnifiedPhotoCollectionViewController(photoProvider: photoProvider)
		controller.settings = settings
		controller.delegate = context.coordinator
		return controller
	}
	
	func updateUIViewController(_ controller: UnifiedPhotoCollectionViewController, context: Context) {
		controller.settings = settings
		
		// Handle scroll to selection
		if scrollToSelection {
			controller.scrollToFirstSelectedItem(animated: true)
			// Reset the trigger
			DispatchQueue.main.async {
				scrollToSelection = false
			}
		}
	}
	#endif
	
	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}
	
	class Coordinator: NSObject, UnifiedPhotoCollectionViewControllerDelegate {
		let parent: UnifiedPhotoCollectionViewRepresentable
		
		init(_ parent: UnifiedPhotoCollectionViewRepresentable) {
			self.parent = parent
		}
		
		func photoCollection(_ controller: UnifiedPhotoCollectionViewController, didSelectPhoto photo: any PhotoItem, allPhotos: [any PhotoItem]) {
			parent.onSelectPhoto?(photo, allPhotos)
		}
		
		func photoCollection(_ controller: UnifiedPhotoCollectionViewController, didUpdateSelection selection: [any PhotoItem]) {
			parent.onSelectionChanged?(selection)
		}
		
		func photoCollection(_ controller: UnifiedPhotoCollectionViewController, didRequestContextMenu photo: any PhotoItem) -> XMenu? {
			// Return nil to use default context menu from photo item
			return nil
		}
	}
}