//
//  MD5Digest+.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/06/12.
//
import CryptoKit
import Foundation

extension Insecure.MD5Digest {
	public var data: Data {
		return self.withUnsafeBytes { buffer in
			Data(buffer)
		}
	}
	init?(rawBytes: Data) {
		guard Insecure.MD5Digest.byteCount == rawBytes.count else { return nil }
		self = rawBytes.withUnsafeBytes { buffer in
			buffer.load(as: Insecure.MD5Digest.self)
		}
	}
}
