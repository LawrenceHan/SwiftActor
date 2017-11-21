//
//  Helper.swift
//  SwiftActor
//
//  Created by Hanguang on 21/11/2017.
//  Copyright © 2017 Hanguang. All rights reserved.
//

import Foundation

extension Array where Element: AnyObject {
    mutating func remove(object: Element) {
        guard let index = index(where: { (obj) -> Bool in obj === object }) else {
            return
        }
        remove(at: index)
    }
    
    func contains(object: Element) -> Bool {
        return contains(where: { (obj) -> Bool in
            return obj === object
        })
    }
}
