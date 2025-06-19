//
//  ThumbnailStripView.swift
//  Photolala
//
//  Native collection view implementation of thumbnail strip for better performance
//

import SwiftUI

struct ThumbnailStripView: XViewControllerRepresentable {
	let photos: [PhotoFile]
	@Binding var currentIndex: Int
	let thumbnailSize: CGSize
	let onTimerExtend: (() -> Void)?

	#if os(macOS)
		func makeNSViewController(context: Context) -> ThumbnailStripViewController {
			let controller = ThumbnailStripViewController(
				photos: photos,
				currentIndex: currentIndex,
				thumbnailSize: thumbnailSize,
				onTimerExtend: onTimerExtend
			)
			controller.coordinator = context.coordinator
			context.coordinator.viewController = controller
			return controller
		}

		func updateNSViewController(_ nsViewController: ThumbnailStripViewController, context: Context) {
			nsViewController.updateCurrentIndex(self.currentIndex, animated: true)
		}
	#else
		func makeUIViewController(context: Context) -> ThumbnailStripViewController {
			let controller = ThumbnailStripViewController(
				photos: photos,
				currentIndex: currentIndex,
				thumbnailSize: thumbnailSize,
				onTimerExtend: onTimerExtend
			)
			controller.coordinator = context.coordinator
			context.coordinator.viewController = controller
			return controller
		}

		func updateUIViewController(_ uiViewController: ThumbnailStripViewController, context: Context) {
			uiViewController.updateCurrentIndex(self.currentIndex, animated: true)
		}
	#endif

	func makeCoordinator() -> Coordinator {
		Coordinator(parent: self)
	}

	class Coordinator: NSObject {
		let parent: ThumbnailStripView
		weak var viewController: ThumbnailStripViewController?

		init(parent: ThumbnailStripView) {
			self.parent = parent
		}

		func didSelectPhoto(at index: Int) {
			self.parent.currentIndex = index
			self.parent.onTimerExtend?()
		}
	}
}
