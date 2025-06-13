//
//  PhotoBrowserView.swift
//  photolala
//
//  Created by Kaz Yoshikawa on 2025/06/12.
//

import SwiftUI

struct PhotoBrowserView: View {
	let directoryPath: NSString
	
	init(directoryPath: NSString) {
		self.directoryPath = directoryPath
	}
	
	var body: some View {
		PhotoCollectionView(directoryPath: directoryPath)
			.navigationTitle(directoryPath.lastPathComponent)
			#if os(macOS)
			.navigationSubtitle(directoryPath as String)
			#endif
	}
}

#Preview {
	PhotoBrowserView(directoryPath: "/Users/example/Pictures")
}
