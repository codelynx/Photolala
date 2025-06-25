//
//  ColorFlag.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/06/25.
//

import Foundation
import SwiftUI

enum ColorFlag: Int, Codable, CaseIterable {
	case red = 1
	case orange = 2
	case yellow = 3
	case green = 4
	case blue = 5
	case purple = 6
	case gray = 7
	
	var color: Color {
		switch self {
		case .red: return .red
		case .orange: return .orange
		case .yellow: return .yellow
		case .green: return .green
		case .blue: return .blue
		case .purple: return .purple
		case .gray: return .gray
		}
	}
	
	#if os(macOS)
	var nsColor: NSColor {
		switch self {
		case .red: return .systemRed
		case .orange: return .systemOrange
		case .yellow: return .systemYellow
		case .green: return .systemGreen
		case .blue: return .systemBlue
		case .purple: return .systemPurple
		case .gray: return .systemGray
		}
	}
	#else
	var uiColor: UIColor {
		switch self {
		case .red: return .systemRed
		case .orange: return .systemOrange
		case .yellow: return .systemYellow
		case .green: return .systemGreen
		case .blue: return .systemBlue
		case .purple: return .systemPurple
		case .gray: return .systemGray
		}
	}
	#endif
	
	var keyboardShortcut: String {
		switch self {
		case .red: return "1"
		case .orange: return "2"
		case .yellow: return "3"
		case .green: return "4"
		case .blue: return "5"
		case .purple: return "6"
		case .gray: return "7"
		}
	}
	
	@ViewBuilder
	var flagView: some View {
		Image(systemName: "flag.fill")
			.foregroundColor(color)
			.font(.system(size: 10))
	}
}

// Extension to maintain sorted order
extension Array where Element == ColorFlag {
	var sorted: [ColorFlag] {
		self.sorted { flag1, flag2 in
			let order1 = ColorFlag.allCases.firstIndex(of: flag1) ?? 0
			let order2 = ColorFlag.allCases.firstIndex(of: flag2) ?? 0
			return order1 < order2
		}
	}
}