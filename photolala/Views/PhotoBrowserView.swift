//
//  PhotoBrowserView.swift
//  photolala
//
//  Created by Kaz Yoshikawa on 2025/06/12.
//

import SwiftUI

struct PhotoBrowserView: View {
	let folderURL: URL
	
	var body: some View {
		PhotoNavigationView(folderURL: folderURL)
	}
}

#Preview {
	PhotoBrowserView(folderURL: URL(fileURLWithPath: "/Users/example/Pictures"))
}