//
//  String+.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/06/12.
//
import Foundation

extension Data {
	var hexadecimalString: String {
		map { String(format: "%02hhx", $0) }.joined().lowercased()
	}

	init?(hexadecimalString: String) {
		if let index = hexadecimalString.first(where: { !($0.isHexDigit || $0.isWhitespace) }) { return nil }
		let hexadecimalString = hexadecimalString.filter(\.isHexDigit)
		if hexadecimalString.count % 2 != 0 { return nil }
		var bytes: [UInt8] = []
		for i in stride(from: 0, to: hexadecimalString.count, by: 2) {
			let substring =
				hexadecimalString[
					hexadecimalString
						.index(hexadecimalString.startIndex, offsetBy: i) ..< hexadecimalString.index(
							hexadecimalString.startIndex,
							offsetBy: i + 2
						)
				]
			if let byteValue = UInt8(substring, radix: 16) {
				bytes.append(byteValue)
			}
		}
		self = Data(bytes)
	}
}
