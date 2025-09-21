//
//  PhotoValidator.swift
//  Photolala
//
//  Image file validation and format detection
//

import Foundation
import ImageIO
import UniformTypeIdentifiers
import OSLog

/// Photo validator for verifying image files
public struct PhotoValidator {
	private static let logger = Logger(subsystem: "com.photolala", category: "PhotoValidator")

	// File size limits
	private static let minFileSize: Int64 = 1024 // 1KB minimum
	private static let maxFileSize: Int64 = 500 * 1024 * 1024 // 500MB maximum

	// Dimension limits
	private static let minDimension = 10
	private static let maxDimension = 65536

	// MARK: - Public API

	/// Validate photo file
	public static func validatePhoto(at url: URL) async throws -> PhotoValidation {
		// Check file exists
		guard FileManager.default.fileExists(atPath: url.path) else {
			throw ValidationError.fileNotFound(url)
		}

		// Check file size
		let fileSize = try url.fileSize()
		guard fileSize >= minFileSize else {
			throw ValidationError.fileTooSmall(fileSize)
		}
		guard fileSize <= maxFileSize else {
			throw ValidationError.fileTooLarge(fileSize)
		}

		// Detect format from header
		let format = try await detectFormat(at: url)

		// Validate image properties
		let properties = try await validateImageProperties(at: url, format: format)

		return PhotoValidation(
			url: url,
			format: format,
			fileSize: fileSize,
			dimensions: properties.dimensions,
			colorSpace: properties.colorSpace,
			hasAlpha: properties.hasAlpha,
			bitDepth: properties.bitDepth,
			isValid: true
		)
	}

	/// Quick validation check (header only)
	public static func quickValidate(at url: URL) async throws -> Bool {
		do {
			_ = try await detectFormat(at: url)
			return true
		} catch {
			return false
		}
	}

	// MARK: - Format Detection

	private static func detectFormat(at url: URL) async throws -> PhotoFormat {
		let handle = try FileHandle(forReadingFrom: url)
		defer { try? handle.close() }

		// Read header bytes (enough for all formats)
		let headerData = try handle.read(upToCount: 32) ?? Data()
		guard headerData.count >= 12 else {
			throw ValidationError.invalidHeader
		}

		let bytes = [UInt8](headerData)

		// JPEG: FF D8 FF
		if bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
			logger.debug("Detected JPEG format")
			return .jpeg
		}

		// PNG: 89 50 4E 47 0D 0A 1A 0A
		if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
			logger.debug("Detected PNG format")
			return .png
		}

		// HEIF/HEIC: Check for ftyp box
		if headerData.count >= 12 {
			let ftyp = String(data: headerData[4..<8], encoding: .ascii)
			if ftyp == "ftyp" {
				let brand = String(data: headerData[8..<12], encoding: .ascii)
				if brand == "heic" || brand == "heix" {
					logger.debug("Detected HEIC format")
					return .heic
				}
				if brand == "heif" || brand == "heim" {
					logger.debug("Detected HEIF format")
					return .heif
				}
			}
		}

		// TIFF: 49 49 2A 00 (little-endian) or 4D 4D 00 2A (big-endian)
		if (bytes[0] == 0x49 && bytes[1] == 0x49 && bytes[2] == 0x2A && bytes[3] == 0x00) ||
		   (bytes[0] == 0x4D && bytes[1] == 0x4D && bytes[2] == 0x00 && bytes[3] == 0x2A) {
			// Check if it's a specific RAW format
			let ext = url.pathExtension.lowercased()
			switch ext {
			case "cr2", "cr3":
				logger.debug("Detected Canon RAW format")
				return .raw(.canon)
			case "nef":
				logger.debug("Detected Nikon RAW format")
				return .raw(.nikon)
			case "arw":
				logger.debug("Detected Sony RAW format")
				return .raw(.sony)
			case "orf":
				logger.debug("Detected Olympus RAW format")
				return .raw(.olympus)
			case "dng":
				logger.debug("Detected DNG format")
				return .raw(.dng)
			case "raf":
				// Fuji RAF has different header
				break
			default:
				logger.debug("Detected TIFF format")
				return .tiff
			}
		}

		// Fuji RAF: 46 55 4A 49 46 49 4C 4D (FUJIFILM)
		if headerData.count >= 8 {
			let fujiHeader = String(data: headerData[0..<8], encoding: .ascii)
			if fujiHeader == "FUJIFILM" {
				logger.debug("Detected Fuji RAW format")
				return .raw(.fuji)
			}
		}

		// WebP: RIFF....WEBP
		if bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 {
			if headerData.count >= 12 {
				let webp = String(data: headerData[8..<12], encoding: .ascii)
				if webp == "WEBP" {
					logger.debug("Detected WebP format")
					return .webp
				}
			}
		}

		throw ValidationError.unsupportedFormat
	}

	// MARK: - Image Properties Validation

	private static func validateImageProperties(at url: URL, format: PhotoFormat) async throws -> ImageProperties {
		// Use ImageIO to get properties
		guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
			throw ValidationError.cannotReadImage
		}

		guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
			throw ValidationError.cannotReadProperties
		}

		// Get dimensions
		let width = properties[kCGImagePropertyPixelWidth] as? Int ?? 0
		let height = properties[kCGImagePropertyPixelHeight] as? Int ?? 0

		guard width >= minDimension && height >= minDimension else {
			throw ValidationError.imageTooSmall(width: width, height: height)
		}

		guard width <= maxDimension && height <= maxDimension else {
			throw ValidationError.imageTooLarge(width: width, height: height)
		}

		// Get color properties
		let colorModel = properties[kCGImagePropertyColorModel] as? String
		let hasAlpha = properties[kCGImagePropertyHasAlpha] as? Bool ?? false
		let bitDepth = properties[kCGImagePropertyDepth] as? Int ?? 8

		let colorSpace: ColorSpace
		if let colorModel = colorModel {
			switch colorModel {
			case String(kCGImagePropertyColorModelRGB):
				colorSpace = .rgb
			case String(kCGImagePropertyColorModelGray):
				colorSpace = .grayscale
			case String(kCGImagePropertyColorModelCMYK):
				colorSpace = .cmyk
			case String(kCGImagePropertyColorModelLab):
				colorSpace = .lab
			default:
				colorSpace = .unknown
			}
		} else {
			colorSpace = .unknown
		}

		return ImageProperties(
			dimensions: CGSize(width: width, height: height),
			colorSpace: colorSpace,
			hasAlpha: hasAlpha,
			bitDepth: bitDepth
		)
	}
}

// MARK: - Supporting Types

/// Photo format enumeration
public enum PhotoFormat: Equatable, Sendable {
	case jpeg
	case heic
	case heif
	case png
	case tiff
	case webp
	case raw(RawFormat)

	public var fileExtension: String {
		switch self {
		case .jpeg: return "jpg"
		case .heic: return "heic"
		case .heif: return "heif"
		case .png: return "png"
		case .tiff: return "tiff"
		case .webp: return "webp"
		case .raw(let format): return format.fileExtension
		}
	}

	nonisolated public var mimeType: String {
		switch self {
		case .jpeg: return "image/jpeg"
		case .heic: return "image/heic"
		case .heif: return "image/heif"
		case .png: return "image/png"
		case .tiff: return "image/tiff"
		case .webp: return "image/webp"
		case .raw: return "image/x-raw"
		}
	}
}

/// RAW format variants
public enum RawFormat: String, Equatable, Sendable {
	case canon = "cr2"
	case canonNew = "cr3"
	case nikon = "nef"
	case sony = "arw"
	case fuji = "raf"
	case olympus = "orf"
	case dng = "dng"
	case panasonic = "rw2"

	var fileExtension: String { rawValue }
}

/// Color space
public enum ColorSpace {
	case rgb
	case grayscale
	case cmyk
	case lab
	case unknown
}

/// Image properties
struct ImageProperties {
	let dimensions: CGSize
	let colorSpace: ColorSpace
	let hasAlpha: Bool
	let bitDepth: Int
}

/// Photo validation result
public struct PhotoValidation {
	public let url: URL
	public let format: PhotoFormat
	public let fileSize: Int64
	public let dimensions: CGSize
	public let colorSpace: ColorSpace
	public let hasAlpha: Bool
	public let bitDepth: Int
	public let isValid: Bool
}

/// Validation errors
public enum ValidationError: LocalizedError {
	case fileNotFound(URL)
	case fileTooSmall(Int64)
	case fileTooLarge(Int64)
	case invalidHeader
	case unsupportedFormat
	case cannotReadImage
	case cannotReadProperties
	case imageTooSmall(width: Int, height: Int)
	case imageTooLarge(width: Int, height: Int)
	case corruptedFile

	public var errorDescription: String? {
		switch self {
		case .fileNotFound(let url):
			return "File not found: \(url.lastPathComponent)"
		case .fileTooSmall(let size):
			return "File too small: \(size) bytes"
		case .fileTooLarge(let size):
			return "File too large: \(size) bytes"
		case .invalidHeader:
			return "Invalid file header"
		case .unsupportedFormat:
			return "Unsupported image format"
		case .cannotReadImage:
			return "Cannot read image file"
		case .cannotReadProperties:
			return "Cannot read image properties"
		case .imageTooSmall(let width, let height):
			return "Image too small: \(width)×\(height)"
		case .imageTooLarge(let width, let height):
			return "Image too large: \(width)×\(height)"
		case .corruptedFile:
			return "File appears to be corrupted"
		}
	}
}