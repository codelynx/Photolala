//
//  PhotoMetadata.swift
//  Photolala
//
//  Created by Assistant on 2025/06/14.
//

import Foundation

class PhotoMetadata: NSObject, Codable {
	let dateTaken: Date?
	let fileModificationDate: Date
	let fileSize: Int64
	let pixelWidth: Int?
	let pixelHeight: Int?
	let cameraMake: String?
	let cameraModel: String?
	let orientation: Int?
	let gpsLatitude: Double?
	let gpsLongitude: Double?
	
	// Computed properties
	var displayDate: Date {
		dateTaken ?? fileModificationDate
	}
	
	var dimensions: String? {
		guard let width = pixelWidth, let height = pixelHeight else { return nil }
		return "\(width) × \(height)"
	}
	
	var cameraInfo: String? {
		switch (cameraMake, cameraModel) {
		case let (make?, model?):
			// Remove manufacturer name from model if it's duplicated
			if model.hasPrefix(make) {
				return model
			}
			return "\(make) \(model)"
		case (nil, let model?):
			return model
		case (let make?, nil):
			return make
		case (nil, nil):
			return nil
		}
	}
	
	var formattedFileSize: String {
		let formatter = ByteCountFormatter()
		formatter.countStyle = .file
		return formatter.string(fromByteCount: fileSize)
	}
	
	init(dateTaken: Date? = nil,
		 fileModificationDate: Date,
		 fileSize: Int64,
		 pixelWidth: Int? = nil,
		 pixelHeight: Int? = nil,
		 cameraMake: String? = nil,
		 cameraModel: String? = nil,
		 orientation: Int? = nil,
		 gpsLatitude: Double? = nil,
		 gpsLongitude: Double? = nil) {
		self.dateTaken = dateTaken
		self.fileModificationDate = fileModificationDate
		self.fileSize = fileSize
		self.pixelWidth = pixelWidth
		self.pixelHeight = pixelHeight
		self.cameraMake = cameraMake
		self.cameraModel = cameraModel
		self.orientation = orientation
		self.gpsLatitude = gpsLatitude
		self.gpsLongitude = gpsLongitude
		super.init()
	}
	
	// Codable requirements
	enum CodingKeys: String, CodingKey {
		case dateTaken, fileModificationDate, fileSize
		case pixelWidth, pixelHeight, cameraMake, cameraModel
		case orientation, gpsLatitude, gpsLongitude
	}
}