//
//  Dispatcher.swift
//  SwiftActor
//
//  Created by Hanguang on 20/11/2017.
//  Copyright © 2017 Hanguang. All rights reserved.
//

import Foundation
import Result

public final class Dispatcher {
    
    // MARK: - typealias
    
    typealias RequestInfo = (requestActor: SwiftActor, watchers: [Handler])
    typealias RemoveWatcherInfo = (watcher: Handler, path: String)
    
    // MARK: - constants
    
    public static let `default` = Dispatcher()
    public let globalQueue: DispatchQueue!
    public var isActorQueue: Bool {
        return DispatchQueue.getSpecific(key: queueSpecificKey) != nil
    }
    
    // MARK: - private
    
    private let mainQueue: DispatchQueue!
    private let highPriorityQueue: DispatchQueue!
    private let networkQueue: DispatchQueue!
    
    // MRAK: - keys
    
    private let queueSpecificKey: DispatchSpecificKey<String>!
    private let mainQueueKey: String!
    private let highPriorityQueueKey: String!
    private let globalQueueKey: String!
    private let networkQueueKey: String!
    
    // MARK: - locks
    
    private var removeWatcherRequestLock = os_unfair_lock()
    private var removeWatcherFromPathRequestLock = os_unfair_lock()
    
    // MARK: - request queues
    
    private var removeWatcherRequests: [Handler] = []
    private var removeWatcherFromPathRequests: [RemoveWatcherInfo] = []
    private var requestsQueue: [String: [SwiftActor]] = [:]
    private var activeRequests: [String: RequestInfo] = [:]
    private var liveWatchers: [String: [Handler]] = [:]
    
    private init() {
        queueSpecificKey = DispatchSpecificKey<String>()
        mainQueueKey = "com.hanguang.actorqueue"
        highPriorityQueueKey = mainQueueKey+"-high"
        globalQueueKey = mainQueueKey+"-global"
        networkQueueKey = mainQueueKey+"-network"
        
        mainQueue = DispatchQueue(label: mainQueueKey, qos: .utility, autoreleaseFrequency: .workItem)
        highPriorityQueue = DispatchQueue(label: highPriorityQueueKey, qos: .userInitiated, autoreleaseFrequency: .workItem, target: mainQueue)
        globalQueue = DispatchQueue(label: globalQueueKey, qos: .utility, autoreleaseFrequency: .workItem, target: mainQueue)
        networkQueue = DispatchQueue(label: networkQueueKey, qos: .utility, autoreleaseFrequency: .workItem, target: mainQueue)
        
        mainQueue.setSpecific(key: queueSpecificKey, value: mainQueueKey)
        highPriorityQueue.setSpecific(key: queueSpecificKey, value: mainQueueKey)
        globalQueue.setSpecific(key: queueSpecificKey, value: mainQueueKey)
        networkQueue.setSpecific(key: queueSpecificKey, value: mainQueueKey)
    }
    
}

// MARK: - registration

public extension Dispatcher {
    public func registerActor(_ actor: SwiftActor.Type) {
        registeredActors[actor.genericPath] = actor
    }
    
    public func requestActor(_ genericPath: String, path: String) -> SwiftActor? {
        guard let actorType = registeredActors[genericPath] else { return nil }
        return actorType.init(path: genericPath)
    }
}

// MARK: - watch & dispatch

public extension Dispatcher {
    
    public func watch(_ paths: String..., watcher: Watcher) {
        guard let handler = watcher.handler else {
            print("===== warning: handler is nil")
            return
        }
        
        let workItem = DispatchWorkItem { [unowned self] in
            for path in paths {
                var watchers: [Handler]? = self.liveWatchers[path]
                if watchers == nil {
                    watchers = []
                    self.liveWatchers[path] = watchers
                }
                if !self.liveWatchers[path]!.contains(object: handler) {
                    self.liveWatchers[path]!.append(handler)
                }
            }
        }
        
        dispatch(workItem)
    }
    
    public func watchGeneric(_ path: String, watcher: Watcher) {
        guard let handler = watcher.handler else {
            print("===== warning: handler is nil")
            return
        }
        
        let workItem = DispatchWorkItem { [unowned self] in
            let genericPath = self.genericPath(with: path)
            var watchers: [Handler]? = self.liveWatchers[genericPath]
            if watchers == nil {
                watchers = []
                self.liveWatchers[genericPath] = watchers
            }
            self.liveWatchers[genericPath]!.append(handler)
        }
        
        dispatch(workItem)
    }
    
    public func remove(watcher: Watcher) {
        guard let handler = watcher.handler else {
            print("===== warning: handler is nil in remove:Watcher")
            return
        }
        removeWatcher(with: handler)
    }
    
    public func removeWatcher(with handler: Handler) {
        var alreadyExecuting = false
        os_unfair_lock_lock(&removeWatcherRequestLock)
        if !removeWatcherRequests.isEmpty {
            alreadyExecuting = true
        }
        removeWatcherRequests.append(handler)
        os_unfair_lock_unlock(&removeWatcherRequestLock)
        
        if alreadyExecuting && !isActorQueue {
            return
        }
        
        let workItem = DispatchWorkItem(qos: .userInitiated) { [unowned self] in
            os_unfair_lock_lock(&self.removeWatcherRequestLock)
            let removeWatchers = self.removeWatcherRequests
            self.removeWatcherRequests.removeAll()
            os_unfair_lock_unlock(&self.removeWatcherRequestLock)
            
            for handler in removeWatchers {
                // Cancel activeRequests
                for path in self.activeRequests.keys {
                    guard var requestInfo = self.activeRequests[path] else {
                        continue
                    }
                    
                    requestInfo.watchers.remove(object: handler)
                    self.activeRequests[path] = requestInfo
                    
                    if requestInfo.watchers.isEmpty {
                        //                        self.scheduleCancelRequest(path: path)
                    }
                }
                
                // Remove liveWatchers
                var keysTobeRemoved: [String] = []
                for key in self.liveWatchers.keys {
                    guard var watchers = self.liveWatchers[key] else {
                        continue
                    }
                    watchers.remove(object: handler)
                    
                    if watchers.isEmpty {
                        keysTobeRemoved.append(key)
                    }
                    
                    self.liveWatchers[key] = watchers
                }
                
                if !keysTobeRemoved.isEmpty {
                    for key in keysTobeRemoved {
                        self.liveWatchers.removeValue(forKey: key)
                    }
                }
            }
        }
        
        dispatch(workItem, queue: highPriorityQueue)
    }
    
    public func remove(watcher: Watcher, path: String) {
        guard let handler = watcher.handler else {
            print("===== warning: handler is nil")
            return
        }
        removeWatcher(with: handler, path: path)
    }
    
    public func removeWatcher(with handler: Handler, path: String) {
        var alreadyExecuting = false
        os_unfair_lock_lock(&removeWatcherFromPathRequestLock)
        if !removeWatcherFromPathRequests.isEmpty {
            alreadyExecuting = true
        }
        removeWatcherFromPathRequests.append((handler, path))
        os_unfair_lock_unlock(&removeWatcherFromPathRequestLock)
        
        if alreadyExecuting && !isActorQueue {
            return
        }
        
        let workItem = DispatchWorkItem(qos: .userInitiated) { [unowned self] in
            os_unfair_lock_lock(&self.removeWatcherFromPathRequestLock)
            let removeWatchersFromPath = self.removeWatcherFromPathRequests
            self.removeWatcherFromPathRequests.removeAll()
            os_unfair_lock_unlock(&self.removeWatcherFromPathRequestLock)
            
            if removeWatchersFromPath.count > 1 {
                print("===== cancelled \(removeWatchersFromPath.count) requests at once")
            }
            
            for (handler, path) in removeWatchersFromPath {
                if path.isEmpty {
                    continue
                }
                
                // Cancel activeRequests
                for path in self.activeRequests.keys {
                    guard var requestInfo = self.activeRequests[path] else {
                        continue
                    }
                    
                    requestInfo.watchers.remove(object: handler)
                    self.activeRequests[path] = requestInfo
                    
                    if requestInfo.watchers.isEmpty {
//                        self.scheduleCancelRequest(path: path)
                    }
                }
                
                // Remove liveWatchers
                if var watchers = self.liveWatchers[path] {
                    watchers.remove(object: handler)
                    if watchers.isEmpty {
                        self.liveWatchers.removeValue(forKey: path)
                    } else {
                        self.liveWatchers[path] = watchers
                    }
                }
            }
        }
        
        dispatch(workItem, queue: highPriorityQueue)
    }
    
    public func removeAllWatchers(_ path: String) {
        let workItem = DispatchWorkItem(qos: .userInitiated) { [unowned self] in
            guard var requestInfo = self.activeRequests[path] else {
                return
            }
            
            requestInfo.watchers.removeAll()
            self.activeRequests[path] = requestInfo
//            self.scheduleCancelRequest(path: path)
        }
        
        dispatch(workItem, queue: highPriorityQueue)
    }
    
    public func dispatch(_ item: DispatchWorkItem, queue: DispatchQueue? = nil) {
        let queue = queue ?? globalQueue
        if isActorQueue {
            item.perform()
        } else {
            queue!.async(execute: item)
        }
    }
    
    public func dispatch<Resource>(_ path: String, resource: Result<Resource, ActorError>, arg: Any? = nil) {
        let workItem = DispatchWorkItem { [unowned self] in
            let genericPath = self.genericPath(with: path)
            
            if let watchers = self.liveWatchers[path] {
                for handler in watchers {
                    var watcher = handler.delegate
                    watcher?.resourceDispatched(path, resource: resource, arg: arg)
                    if handler.releaseOnMainQueue {
                        DispatchQueue.main.async {
                            _ = watcher.self
                        }
                    }
                    watcher = nil
                }
            }
            
            if genericPath != path {
                if let watchers = self.liveWatchers[genericPath] {
                    for handler in watchers {
                        var watcher = handler.delegate
                        watcher?.resourceDispatched(path, resource: resource, arg: arg)
                        if handler.releaseOnMainQueue {
                            DispatchQueue.main.async {
                                _ = watcher.self
                            }
                        }
                        watcher = nil
                    }
                }
            }
        }
        
        dispatch(workItem)
    }
    
    public func dispatchMessage(watcher path: String, messageType: String? = nil, message: Any? = nil) {
        let workItem = DispatchWorkItem { [unowned self] in
            let genericPath = self.genericPath(with: path)
            
            if let watchers = self.liveWatchers[path] {
                for handler in watchers {
                    handler.sendWatcherMessage(path, messageType: messageType, message: message)
                }
            }
            
            if genericPath != path {
                if let watchers = self.liveWatchers[genericPath] {
                    for handler in watchers {
                        handler.sendWatcherMessage(path, messageType: messageType, message: message)
                    }
                }
            }
        }
        
        dispatch(workItem)
    }
    
    public func completed(_ path: String, result: Result<Any, ActorError>) {
        let workItem = DispatchWorkItem { [unowned self] in
            guard let requestInfo = self.activeRequests[path] else {
                return
            }
            
            var watchers = requestInfo.watchers
            self.activeRequests.removeValue(forKey: path)
            
            for handler in watchers {
                var watcher = handler.delegate
                watcher?.completed(path, result: result)
                
                if handler.releaseOnMainQueue {
                    DispatchQueue.main.async {
                        _ = watcher.self
                    }
                }
                watcher = nil
            }
            
            watchers.removeAll()
            
            guard let requestQueueName = requestInfo.requestActor.requestQueueName else {
                return
            }
            
//            self.removeRequestFromQueueAndProceedIfFirst(
//                name: requestQueueName, fromRequestActor: requestActor
//            )
        }
        
        dispatch(workItem)
    }
    
    public func request(_ path: String, options: [AnyHashable: Any]? = nil, watcher: Watcher) {
//        _requestGeneric(
//            joinOnly: false,
//            inCurrentQueue: false,
//            path: path, options:
//            options,
//            flags: flags,
//            watcher: watcher,
//            completion: completion
//        )
    }
    
    
}

// MARK: - helper

extension Dispatcher {
    public func rejoin(_ genericPath: String, prefix: String, watcher: Watcher) -> [String] {
        var rejoinPaths: [String] = []
        for path in activeRequests.keys {
            if path == genericPath ||
                self.genericPath(with: path) == genericPath,
                (prefix.isEmpty || path.hasPrefix(prefix)) {
                rejoinPaths.append(path)
            }
        }
        
        for path in rejoinPaths {
            //            _requestGeneric(joinOnly: true, inCurrentQueue: true, path: path, options: [:], flags: 0, watcher: watcher, completion: nil)
        }
        
        return rejoinPaths
    }
    
    public func isActorRunning(_ path: String) -> Bool {
        if let _ = activeRequests[path] {
            return true
        }
        return false
    }
    
    public func isExecutingActors(genericPath: String) -> Bool {
        if !isActorQueue {
            print("===== warning: should be called from actor queue")
            return false
        }
        
        var result: Bool = false
        for (_, requestInfo) in activeRequests {
            if genericPath == type(of: requestInfo.requestActor).genericPath {
                result = true
                break
            }
        }
        
        return result
    }
    
    public func isExecutingActors(pathPrefix: String) -> Bool {
        if isActorQueue {
            print("===== warning: should be called from actor queue")
            return false
        }
        
        var result = false
        for (path, _) in activeRequests {
            if path.hasPrefix(pathPrefix) {
                result = true
                break
            }
        }
        
        return result
    }
    
    public func executingActors(pathPrefix: String) -> [SwiftActor] {
        if !isActorQueue {
            print("===== warning: should be called from actor queue")
            return []
        }
        
        var array: [SwiftActor] = []
        for (path, requestInfo) in activeRequests {
            if path.hasPrefix(pathPrefix) {
                array.append(requestInfo.requestActor)
            }
        }
        
        return array
    }
    
    public func executingActor(path: String) -> SwiftActor? {
        if !isActorQueue {
            print("===== warning: should be called from actor queue")
            return nil
        }
        
        guard let requestInfo = activeRequests[path] else {
            return nil
        }
        
        return requestInfo.requestActor
    }
}

// MARK: - internal

extension Dispatcher {
    func genericPath(with path: String) -> String {
        if path.isEmpty {
            return ""
        }
        
        var newPath: String = ""
        var skip: Bool = false
        var skippedCharacters: Bool = false
        
        for c in path {
            if c == "(" {
                skip = true
                skippedCharacters = true
                newPath.append("@")
            } else if c == ")" {
                skip = false
            } else if !skip {
                newPath.append(c)
            }
        }
        
        if !skippedCharacters {
            return path
        }
        
        return newPath
    }
}


private var registeredActors: [String: SwiftActor.Type] = [:]

// MARK: - default shared instance

public let Actor = Dispatcher.default
