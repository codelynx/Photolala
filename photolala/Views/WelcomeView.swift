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
			Text("Choose a folder to browse photos")
				.font(.headline)
				.foregroundStyle(.secondary)
			
			// Select folder button
			Button(action: selectFolder) {
				Label("Select Folder", systemImage: "folder")
					.frame(minWidth: 200)
			}
			.controlSize(.large)
			#if os(macOS)
			.buttonStyle(.borderedProminent)
			#endif
			
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
		.navigationDestination(isPresented: $navigateToPhotoBrowser) {
			if let folder = selectedFolder {
				PhotoBrowserView(directoryPath: folder.path as NSString)
			}
		}
		#endif
		#if os(macOS)
		.fileImporter(
			isPresented: $showingFolderPicker,
			allowedContentTypes: [.folder],
			allowsMultipleSelection: false
		) { result in
			switch result {
			case .success(let urls):
				if let url = urls.first {
					selectedFolder = url
					openPhotoBrowser(for: url)
				}
			case .failure(let error):
				print("Folder selection error: \(error)")
			}
		}
		#elseif os(iOS)
		.sheet(isPresented: $showingFolderPicker) {
			DocumentPickerView(selectedFolder: $selectedFolder) { url in
				openPhotoBrowser(for: url)
			}
		}
		#endif
	}
	
	private func selectFolder() {
		#if os(macOS)
		showingFolderPicker = true
		#elseif os(iOS)
		showingFolderPicker = true
		#endif
	}
	
	private func openPhotoBrowser(for url: URL) {
		#if os(macOS)
		openWindow(value: url)
		#else
		navigateToPhotoBrowser = true
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
				parent.selectedFolder = url
				// Access the folder with security scope
				if url.startAccessingSecurityScopedResource() {
					// Keep access for later use
					url.stopAccessingSecurityScopedResource()
				}
				parent.onSelectFolder(url)
			}
			parent.dismiss()
		}
		
		func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
			parent.dismiss()
		}
	}
}
#endif

#Preview {
	WelcomeView()
}
