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
	@State private var showingSamplePhotos = false
	@State private var showingResourceTest = false
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
			
			// Sample photos button (for testing)
			Button(action: openSamplePhotos) {
				Label("View Sample Photos", systemImage: "photo.on.rectangle")
					.frame(minWidth: 200)
			}
			.controlSize(.regular)
			#if os(macOS)
			.buttonStyle(.bordered)
			#endif
			
			// Test resources button
			Button(action: testResources) {
				Label("Test Resources", systemImage: "hammer.circle")
					.frame(minWidth: 200)
			}
			.controlSize(.small)
			.foregroundStyle(.secondary)
			
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
				PhotoBrowserView(folderURL: folder)
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
			DocumentPickerView(selectedFolder: $selectedFolder)
		}
		#endif
		.sheet(isPresented: $showingResourceTest) {
			ResourceTestView()
		}
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
	
	private func openSamplePhotos() {
		// Check if Photos resource exists
		ResourceHelper.checkPhotosResource()
		
		// Try to open the Photos resource directory
		if let photosURL = Bundle.main.url(forResource: "Photos", withExtension: nil) {
			selectedFolder = photosURL
			openPhotoBrowser(for: photosURL)
		} else {
			print("Photos resource directory not found")
			// Use virtual bundle photos URL as fallback
			let bundleURL = BundlePhotosHelper.virtualBundlePhotosURL
			selectedFolder = bundleURL
			openPhotoBrowser(for: bundleURL)
		}
	}
	
	private func testResources() {
		showingResourceTest = true
	}
}

#if os(iOS)
import UIKit

struct DocumentPickerView: UIViewControllerRepresentable {
	@Binding var selectedFolder: URL?
	@Environment(\.dismiss) private var dismiss
	
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