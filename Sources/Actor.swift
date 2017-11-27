//
//  Actor.swift
//  Actor
//
//  Created by Hanguang on 20/11/2017.
//  Copyright © 2017 Hanguang. All rights reserved.
//

import Foundation

/// Abstract Class
open class Actor {
    open class var genericPath: String {
        fatalError("===== error: Actor.genericPath: no default implementation provided.")
    }
    
    open let path: String
    open var requestQueueName: String?
    open var storedOptions: [String: Any]?
    open var cancelTokens: [CancelToken] = []
    open var isCancelled: Bool = false
    
    public required init(path: String) {
        self.path = path
    }
    
    open func prepare(options: [String: Any]?) {
    }
    
    open func execute(options: [String: Any]?) {
    }
    
    open func cancel() {
        if !cancelTokens.isEmpty {
            for token in cancelTokens {
                token.cancel()
            }
            cancelTokens.removeAll()
        }
        isCancelled = true
    }
    
    open func addCancelToken(token: CancelToken) {
        cancelTokens.append(token)
    }
    
    open func watcherJoined(_ handler: Handler, options: [String: Any]?, waitingInActorQueue: Bool) {
    }
}

public protocol CancelToken {
    func cancel()
}
