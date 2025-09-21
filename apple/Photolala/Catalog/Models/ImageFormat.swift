//
//  ImageFormat.swift
//  Photolala
//
//  Image format detection and metadata
//

import Foundation

/// Supported image formats with detection and metadata
public enum ImageFormat: String, CaseIterable, Sendable, Codable {
	case jpeg = "JPEG"
	case png = "PNG"
	case heif = "HEIF"
	case tiff = "TIFF"
	case gif = "GIF"
	case webp = "WEBP"
	case bmp = "BMP"
	case rawCR2 = "RAW-CR2"
	case rawNEF = "RAW-NEF"
	case rawARW = "RAW-ARW"
	case rawDNG = "RAW-DNG"
	case rawORF = "RAW-ORF"
	case rawRAF = "RAW-RAF"
	case unknown = "UNKNOWN"

	/// Get preferred file extension for this format
	public var fileExtension: String {
		switch self {
		case .jpeg: return "jpg"
		case .png: return "png"
		case .heif: return "heic"
		case .tiff: return "tiff"
		case .gif: return "gif"
		case .webp: return "webp"
		case .bmp: return "bmp"
		case .rawCR2: return "cr2"
		case .rawNEF: return "nef"
		case .rawARW: return "arw"
		case .rawDNG: return "dng"
		case .rawORF: return "orf"
		case .rawRAF: return "raf"
		case .unknown: return "dat"
		}
	}

	/// All possible extensions for this format
	public var allExtensions: [String] {
		switch self {
		case .jpeg: return ["jpg", "jpeg", "jpe", "jfif"]
		case .png: return ["png"]
		case .heif: return ["heic", "heif", "hif"]
		case .tiff: return ["tiff", "tif"]
		case .gif: return ["gif"]
		case .webp: return ["webp"]
		case .bmp: return ["bmp", "dib"]
		case .rawCR2: return ["cr2"]
		case .rawNEF: return ["nef"]
		case .rawARW: return ["arw"]
		case .rawDNG: return ["dng"]
		case .rawORF: return ["orf"]
		case .rawRAF: return ["raf"]
		case .unknown: return ["dat"]
		}
	}

	/// MIME type for web serving
	public var mimeType: String {
		switch self {
		case .jpeg: return "image/jpeg"
		case .png: return "image/png"
		case .heif: return "image/heif"
		case .tiff: return "image/tiff"
		case .gif: return "image/gif"
		case .webp: return "image/webp"
		case .bmp: return "image/bmp"
		case .rawCR2: return "image/x-canon-cr2"
		case .rawNEF: return "image/x-nikon-nef"
		case .rawARW: return "image/x-sony-arw"
		case .rawDNG: return "image/x-adobe-dng"
		case .rawORF: return "image/x-olympus-orf"
		case .rawRAF: return "image/x-fuji-raf"
		case .unknown: return "application/octet-stream"
		}
	}

	/// Human-readable description
	public var description: String {
		switch self {
		case .jpeg: return "JPEG Image"
		case .png: return "PNG Image"
		case .heif: return "HEIF/HEIC Image"
		case .tiff: return "TIFF Image"
		case .gif: return "GIF Image"
		case .webp: return "WebP Image"
		case .bmp: return "Bitmap Image"
		case .rawCR2: return "Canon RAW"
		case .rawNEF: return "Nikon RAW"
		case .rawARW: return "Sony RAW"
		case .rawDNG: return "Adobe DNG"
		case .rawORF: return "Olympus RAW"
		case .rawRAF: return "Fujifilm RAW"
		case .unknown: return "Unknown Format"
		}
	}

	/// Initialize from file extension
	public init(fromExtension ext: String) {
		let lowercased = ext.lowercased()

		for format in ImageFormat.allCases {
			if format.allExtensions.contains(lowercased) {
				self = format
				return
			}
		}

		self = .unknown
	}
}

// MARK: - Format Detection

public extension ImageFormat {
	/// Detect image format from file data using magic bytes
	static func detect(from url: URL) -> ImageFormat {
		guard let data = try? Data(contentsOf: url, options: .alwaysMapped),
		      data.count >= 16 else {
			return .unknown
		}

		return detect(from: data)
	}

	/// Detect image format from data using magic bytes
	static func detect(from data: Data) -> ImageFormat {
		guard data.count >= 16 else { return .unknown }

		let bytes = [UInt8](data.prefix(32)) // Read more bytes for complex formats

		// JPEG: FF D8 FF
		if bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
			return .jpeg
		}

		// PNG: 89 50 4E 47 0D 0A 1A 0A
		if bytes.count >= 8 &&
		   bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 &&
		   bytes[4] == 0x0D && bytes[5] == 0x0A && bytes[6] == 0x1A && bytes[7] == 0x0A {
			return .png
		}

		// GIF: 47 49 46 38 37/39 61 (GIF87a or GIF89a)
		if bytes.count >= 6 &&
		   bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38 &&
		   (bytes[4] == 0x37 || bytes[4] == 0x39) && bytes[5] == 0x61 {
			return .gif
		}

		// BMP: 42 4D (BM)
		if bytes[0] == 0x42 && bytes[1] == 0x4D {
			return .bmp
		}

		// WebP: 52 49 46 46 xx xx xx xx 57 45 42 50 (RIFF....WEBP)
		if bytes.count >= 12 &&
		   bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
		   bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50 {
			return .webp
		}

		// TIFF: 49 49 2A 00 (little-endian) or 4D 4D 00 2A (big-endian)
		if (bytes[0] == 0x49 && bytes[1] == 0x49 && bytes[2] == 0x2A && bytes[3] == 0x00) ||
		   (bytes[0] == 0x4D && bytes[1] == 0x4D && bytes[2] == 0x00 && bytes[3] == 0x2A) {

			// Check for Canon CR2 (TIFF-based)
			if bytes.count >= 10 &&
			   bytes[0] == 0x49 && bytes[1] == 0x49 && bytes[2] == 0x2A && bytes[3] == 0x00 &&
			   bytes[8] == 0x43 && bytes[9] == 0x52 {
				return .rawCR2
			}

			// Check for Olympus ORF (TIFF-based)
			if data.count >= 32 {
				let marker = data[8..<12]
				if marker == Data("IIRO".utf8) || marker == Data("IIRS".utf8) {
					return .rawORF
				}
			}

			// Check for DNG (TIFF-based with specific tags)
			// This is simplified - proper DNG detection would read IFD tags
			if data.count >= 100 {
				let dngMarker = "Adobe".data(using: .ascii)!
				if data.range(of: dngMarker) != nil {
					return .rawDNG
				}
			}

			// Default to TIFF if no specific RAW format detected
			return .tiff
		}

		// HEIF/HEIC: Based on ISO Base Media File Format (ftyp box)
		if bytes.count >= 12 {
			// Check for 'ftyp' at offset 4
			if bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70 {
				let brand = String(bytes: bytes[8..<12], encoding: .ascii) ?? ""

				// Check various HEIF brands
				if brand == "heic" || brand == "heix" || brand == "hevc" ||
				   brand == "hevx" || brand == "heim" || brand == "heis" ||
				   brand == "hevm" || brand == "hevs" || brand == "mif1" {
					return .heif
				}
			}
		}

		// Sony ARW (Based on TIFF but with Sony markers)
		if data.count >= 32 &&
		   bytes[0] == 0x49 && bytes[1] == 0x49 && bytes[2] == 0x2A && bytes[3] == 0x00 {
			let sonyMarker = "SONY".data(using: .ascii)!
			if data.range(of: sonyMarker, in: 0..<min(1024, data.count)) != nil {
				return .rawARW
			}
		}

		// Nikon NEF (TIFF-based with Nikon markers)
		if bytes[0] == 0x4D && bytes[1] == 0x4D && bytes[2] == 0x00 && bytes[3] == 0x2A {
			if data.count >= 100 {
				let nikonMarker = "NIKON".data(using: .ascii)!
				if data.range(of: nikonMarker, in: 0..<min(1024, data.count)) != nil {
					return .rawNEF
				}
			}
		}

		// Fujifilm RAF
		if bytes.count >= 16 &&
		   bytes[0] == 0x46 && bytes[1] == 0x55 && bytes[2] == 0x4A && bytes[3] == 0x49 &&
		   bytes[4] == 0x46 && bytes[5] == 0x49 && bytes[6] == 0x4C && bytes[7] == 0x4D {
			return .rawRAF
		}

		return .unknown
	}

	/// Detect format from first 4KB (used during FastPhotoKey creation)
	static func detectFromHead(_ headData: Data) -> ImageFormat {
		return detect(from: headData)
	}
}