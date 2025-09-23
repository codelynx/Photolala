//
//  DocumentPickerView.swift
//  Photolala
//
//  UIDocumentPickerViewController wrapper for proper navigation timing
//

#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers

struct DocumentPickerView: UIViewControllerRepresentable {
	@Binding var isPresented: Bool
	let contentTypes: [UTType]
	let onPick: (URL, Bool) -> Void

	func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
		let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes)
		picker.delegate = context.coordinator
		picker.allowsMultipleSelection = false
		return picker
	}

	func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
		// No updates needed
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}

	class Coordinator: NSObject, UIDocumentPickerDelegate {
		let parent: DocumentPickerView

		init(_ parent: DocumentPickerView) {
			self.parent = parent
		}

		func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
			guard let url = urls.first else { return }

			// Start security scope access
			let started = url.startAccessingSecurityScopedResource()

			// Dismiss the picker first to avoid DocumentManager crash
			parent.isPresented = false

			// Call the completion handler after a slight delay to ensure dismissal
			DispatchQueue.main.async {
				self.parent.onPick(url, started)
			}
		}

		func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
			parent.isPresented = false
		}
	}
}
#endif