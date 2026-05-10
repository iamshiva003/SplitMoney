//
//  Item.swift
//  SplitMoney
//
//  Created by Shivakumar Patil on 10/05/26.
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
