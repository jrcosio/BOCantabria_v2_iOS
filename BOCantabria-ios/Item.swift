//
//  Item.swift
//  BOCantabria-ios
//
//  Created by José Ramón Blanco on 10/09/2026.
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
