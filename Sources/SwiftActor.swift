//
//  SwiftActor.swift
//  SwiftActor
//
//  Created by Hanguang on 20/11/2017.
//  Copyright © 2017 Hanguang. All rights reserved.
//

import Foundation

public protocol SwiftActor {
    
    static var genericPath: String { get }
    
    var path: String { get set }
    var requestQueueName: String? { get set }
    var storedOptions: [String: Any]? { get set }
    var cancelTimeout: TimeInterval { get set }
    var cancelTokens: [CancelToken] { get set }
    var isCancelled: Bool { get set }
    
    init(path: String)
    
    mutating func prepare(options: [String: Any]?)
    mutating func execute(options: [String: Any]?)
    mutating func cancel()
    mutating func addCancelToken(token: CancelToken)
    mutating func watcherJoined(_ watcherHandler: Handler, options: [AnyHashable: Any]?, waitingInActorQueue: Bool)
}

public extension SwiftActor {
    mutating func prepare(options: [String: Any]?) {
    }
    
    mutating func execute(options: [String: Any]?) {
    }
    
    mutating func cancel() {
        if !cancelTokens.isEmpty {
            for token in cancelTokens {
                token.cancel()
            }
            cancelTokens.removeAll()
        }
        isCancelled = true
    }
    
    mutating func addCancelToken(token: CancelToken) {
        cancelTokens.append(token)
    }
    
    mutating func watcherJoined(_ watcherHandler: Handler, options: [AnyHashable: Any]?, waitingInActorQueue: Bool) {
    }
}

public extension SwiftActor {
    var requestQueueName: String? { return nil }
    var storedOptions: [String: Any]? { return nil }
    var cancelTimeout: TimeInterval? { return 0 }
    var cancelToken: [CancelToken] { return [] }
    var isCancelled: Bool { return false }
}

public protocol CancelToken {
    func cancel()
}
