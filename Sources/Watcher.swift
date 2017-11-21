//
//  Watcher.swift
//  SwiftActor
//
//  Created by Hanguang on 20/11/2017.
//  Copyright © 2017 Hanguang. All rights reserved.
//

import Foundation
import CoreGraphics
import Result

public protocol Watcher: class {
    var handler: Handler? { get }
    
    func reportedProgress(_ path: String, progress: CGFloat)
    func resourceDispatched(_ path: String, resource: Any, arg: Any?)
    func completed(_ path: String, result: Result<Any, ActorError>)
    func requested(_ action: String, options: [AnyHashable: Any]?)
    
    func watcherMessageReceived(_ path: String, messageType: String?, message: Any?)
    func actorMessageReceived(_ path: String, messageType: String?, message: Any?)
}
