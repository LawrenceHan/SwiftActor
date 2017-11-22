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

public func DispatchOnMainQueue(_ closure: @escaping () -> Void) {
    if Thread.isMainThread {
        closure()
    } else {
        DispatchQueue.main.async {
            closure()
        }
    }
}

public func DispatchAfter(_ delay: TimeInterval, queue: DispatchQueue, closure: @escaping () -> Void) {
    queue.asyncAfter(deadline: .now()+delay, execute: closure)
}
