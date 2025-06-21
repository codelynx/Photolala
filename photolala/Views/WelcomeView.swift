//
//  WelcomeView.swift
//  photolala
//
//  Created by Kaz Yoshikawa on 2025/06/12.
//

import SwiftUI

struct WelcomeView: View {
	@State private var selectedFolder: URL?
	@State private var showingFolderPicker = false
	@State private var navigateToPhotoBrowser = false
	@State private var navigateToPhotoLibrary = false
	#if os(macOS)
		@Environment(\.openWindow) private var openWindow
	#endif

	var body: some View {
		VStack(spacing: 30) {
			// App icon and name
			VStack(spacing: 16) {
				Image(systemName: "photo.stack")
					.font(.system(size: 80))
					.foregroundStyle(.tint)

				Text("Photolala")
					.font(.largeTitle)
					.fontWeight(.medium)
			}

			// Welcome message
			Text("Choose a source to browse photos")
				.font(.headline)
				.foregroundStyle(.secondary)

			// Source selection buttons
			VStack(spacing: 12) {
				// Select folder button
				Button(action: self.selectFolder) {
					Label("Browse Folder", systemImage: "folder")
						.frame(minWidth: 200)
				}
				.controlSize(.large)
				#if os(macOS)
					.buttonStyle(.borderedProminent)
				#endif
				
				// Photos Library button
				Button(action: self.openPhotoLibrary) {
					Label("Photos Library", systemImage: "photo.on.rectangle")
						.frame(minWidth: 200)
				}
				.controlSize(.large)
				#if os(macOS)
					.buttonStyle(.bordered)
				#endif
			}

			// Selected folder display
			if let folder = selectedFolder {
				VStack(spacing: 8) {
					Text("Selected:")
						.font(.caption)
						.foregroundStyle(.secondary)

					Text(folder.lastPathComponent)
						.font(.body)
						.fontWeight(.medium)

					Text(folder.path)
						.font(.caption)
						.foregroundStyle(.secondary)
						.lineLimit(1)
						.truncationMode(.middle)
						.frame(maxWidth: 300)
				}
				.padding()
				.background(Color.gray.opacity(0.1))
				.cornerRadius(8)
			}
		}
		.padding(40)
		.frame(minWidth: 400, minHeight: 300)
		#if os(iOS)
			.navigationDestination(isPresented: self.$navigateToPhotoBrowser) {
				if let folder = selectedFolder {
					DirectoryPhotoBrowserView(directoryPath: folder.path as NSString)
				}
			}
			.navigationDestination(isPresented: self.$navigateToPhotoLibrary) {
				ApplePhotosBrowserView()
			}
		#endif
		#if os(macOS)
		.fileImporter(
			isPresented: self.$showingFolderPicker,
			allowedContentTypes: [.folder],
			allowsMultipleSelection: false
		) { result in
			switch result {
			case let .success(urls):
				if let url = urls.first {
					self.selectedFolder = url
					self.openPhotoBrowser(for: url)
				}
			case let .failure(error):
				print("Folder selection error: \(error)")
			}
		}
		#elseif os(iOS)
		.sheet(isPresented: self.$showingFolderPicker) {
			DocumentPickerView(selectedFolder: self.$selectedFolder) { url in
				self.openPhotoBrowser(for: url)
			}
		}
		#endif
	}

	private func selectFolder() {
		#if os(macOS)
			self.showingFolderPicker = true
		#elseif os(iOS)
			self.showingFolderPicker = true
		#endif
	}

	private func openPhotoBrowser(for url: URL) {
		#if os(macOS)
			self.openWindow(value: url)
		#else
			self.navigateToPhotoBrowser = true
		#endif
	}
	
	private func openPhotoLibrary() {
		#if os(macOS)
			// For macOS, we need to update PhotolalaApp to handle this
			// For now, open a new window with a special URL
			if let url = URL(string: "photolala://photos-library") {
				self.openWindow(value: url)
			}
		#else
			self.navigateToPhotoLibrary = true
		#endif
	}
}

#if os(iOS)
	import UIKit

	struct DocumentPickerView: UIViewControllerRepresentable {
		@Binding var selectedFolder: URL?
		@Environment(\.dismiss) private var dismiss
		let onSelectFolder: (URL) -> Void

		func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
			let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
			picker.delegate = context.coordinator
			picker.allowsMultipleSelection = false
			return picker
		}

		func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

		func makeCoordinator() -> Coordinator {
			Coordinator(self)
		}

		class Coordinator: NSObject, UIDocumentPickerDelegate {
			let parent: DocumentPickerView

			init(_ parent: DocumentPickerView) {
				self.parent = parent
			}

			func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
				if let url = urls.first {
					self.parent.selectedFolder = url
					// Access the folder with security scope
					if url.startAccessingSecurityScopedResource() {
						// Keep access for later use
						url.stopAccessingSecurityScopedResource()
					}
					self.parent.onSelectFolder(url)
				}
				self.parent.dismiss()
			}

			func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
				self.parent.dismiss()
			}
		}
	}
#endif

#Preview {
	WelcomeView()
}
