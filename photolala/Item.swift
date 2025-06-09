//
//  Item.swift
//  photolala
//
//  Created by Kaz Yoshikawa on 2025/06/09.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
