//
//  PhotoGroup.swift
//  Photolala
//
//  Created by Assistant on 2025/06/15.
//

import Foundation

struct PhotoGroup: Identifiable {
	let id = UUID()
	let title: String
	let photos: [PhotoReference]
	let dateRepresentative: Date

	var photoCount: Int {
		self.photos.count
	}
}
