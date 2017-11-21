//
//  Handler.swift
//  SwiftActor
//
//  Created by Hanguang on 20/11/2017.
//  Copyright © 2017 Hanguang. All rights reserved.
//

import Foundation

public class Handler {
    
    public weak var delegate: Watcher? {
        get {
            var result: Watcher?
            os_unfair_lock_lock(&lock)
            result = _delegate
            os_unfair_lock_unlock(&lock)
            return result
        }
        set {
            os_unfair_lock_lock(&lock)
            _delegate = newValue
            os_unfair_lock_unlock(&lock)
        }
    }
    public let releaseOnMainQueue: Bool
    
    private var lock: os_unfair_lock = os_unfair_lock()
    private weak var _delegate: Watcher?
    
    public init(_ delegate: Watcher, releaseOnMainQueue: Bool = false) {
        self._delegate = delegate
        self.releaseOnMainQueue = releaseOnMainQueue
    }
}

// MARK: - functions

public extension Handler {
    public func reset() {
        os_unfair_lock_lock(&lock)
        _delegate = nil
        os_unfair_lock_unlock(&lock)
    }
    
    public func send(_ action: String, options: [AnyHashable: Any]? = nil) {
        _delegate?.requested(action, options: options)
        if releaseOnMainQueue && !Thread.isMainThread {
            DispatchQueue.main.async {
                _ = self._delegate.self
            }
        }
    }
    
    public func sendWatcherMessage(_ path: String, messageType: String? = nil, message: Any? = nil) {
        _delegate?.watcherMessageReceived(path, messageType: messageType, message: message)
        if releaseOnMainQueue && !Thread.isMainThread {
            DispatchQueue.main.async {
                _ = self._delegate.self
            }
        }
    }
    
    public func sendActorMessage(_ path: String, messageType: String? = nil, message: Any? = nil) {
        _delegate?.actorMessageReceived(path, messageType: messageType, message: message)
        if releaseOnMainQueue && !Thread.isMainThread {
            DispatchQueue.main.async {
                _ = self._delegate.self
            }
        }
    }
    
    public func sendResource(_ path: String, resource: Any? = nil, arg: Any? = nil) {
        _delegate?.resourceDispatched(path, resource: resource, arg: arg)
        if releaseOnMainQueue && !Thread.isMainThread {
            DispatchQueue.main.async {
                _ = self._delegate.self
            }
        }
    }
    
}
