//
//  Dispatcher.swift
//  SwiftActor
//
//  Created by Hanguang on 20/11/2017.
//  Copyright © 2017 Hanguang. All rights reserved.
//

import Foundation
import CoreGraphics

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
    
    // MRAK: - keys
    
    private let queueSpecificKey: DispatchSpecificKey<String>!
    private let mainQueueKey: String!
    private let highPriorityQueueKey: String!
    private let globalQueueKey: String!
    
    // MARK: - locks
    
    private var removeWatcherRequestLock = os_unfair_lock()
    private var removeWatcherFromPathRequestLock = os_unfair_lock()
    
    // MARK: - request queues
    
    private var removeWatcherRequests: [Handler] = []
    private var removeWatcherFromPathRequests: [RemoveWatcherInfo] = []
    private var requestQueues: [String: [SwiftActor]] = [:]
    private var activeRequests: [String: RequestInfo] = [:]
    private var liveWatchers: [String: [Handler]] = [:]
    
    private init() {
        queueSpecificKey = DispatchSpecificKey<String>()
        mainQueueKey = "com.hanguang.actorqueue"
        highPriorityQueueKey = mainQueueKey+"-high"
        globalQueueKey = mainQueueKey+"-global"
        
        mainQueue = DispatchQueue(label: mainQueueKey, qos: .utility, autoreleaseFrequency: .workItem)
        highPriorityQueue = DispatchQueue(label: highPriorityQueueKey, qos: .userInitiated, autoreleaseFrequency: .workItem, target: mainQueue)
        globalQueue = DispatchQueue(label: globalQueueKey, qos: .utility, autoreleaseFrequency: .workItem, target: mainQueue)
        
        mainQueue.setSpecific(key: queueSpecificKey, value: mainQueueKey)
        highPriorityQueue.setSpecific(key: queueSpecificKey, value: mainQueueKey)
        globalQueue.setSpecific(key: queueSpecificKey, value: mainQueueKey)
    }
    
}

// MARK: - registration

public extension Dispatcher {
    public func register(_ actor: SwiftActor.Type) {
        registeredActors[actor.genericPath] = actor
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
                        self.cancelRequest(path)
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
                        self.cancelRequest(path)
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
            self.cancelRequest(path)
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
    
    public func dispatch(_ path: String, resource: Any, arg: Any? = nil) {
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
    
    public func dispatchProgress(_ path: String, progress: CGFloat) {
        let workItem = DispatchWorkItem { [unowned self] in
            guard let requestInfo = self.activeRequests[path] else {
                return
            }
            
            for handler in requestInfo.watchers {
                var watcher = handler.delegate
                watcher?.reportedProgress(path, progress: progress)
                
                if handler.releaseOnMainQueue {
                    DispatchQueue.main.async {
                        _ = watcher.self
                    }
                }
                watcher = nil
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
    
    public func dispatchActorMessage(watcher path: String, messageType: String? = nil, message: Any? = nil) {
        let workItem = DispatchWorkItem {
            guard let requestInfo = self.activeRequests[path] else {
                return
            }
            
            for handler in requestInfo.watchers {
                handler.sendActorMessage(path, messageType: messageType, message: message)
            }
        }
        
        dispatch(workItem)
    }
    
    public func completed(_ path: String, result: Result) {
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
            
            self.removeRequestAndExecuteNextIn(requestQueueName, requestActor: requestInfo.requestActor)
        }
        
        dispatch(workItem)
    }
    
    public func request(_ path: String, options: [String: Any]? = nil, watcher: Watcher) {
        request(joinOnly: false, inCurrentQueue: false, path: path, options: options, watcher: watcher)
    }
    
    
}

// MARK: - helper

public extension Dispatcher {
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
            request(joinOnly: true, inCurrentQueue: true, path: path, options: [:], watcher: watcher)
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
    
    public func dumpActorState() {
        let workItem = DispatchWorkItem { [unowned self] in
            print("===== Actor State =====")
            
            print("\(self.liveWatchers.count) live watchers")
            for (path, watchers) in self.liveWatchers {
                print("    \(path)")
                for handler in watchers {
                    if let watcher = handler.delegate {
                        print("        \(watcher)")
                    }
                }
            }
            
            print("\(self.activeRequests.count) requests")
            for (path, _) in self.activeRequests {
                print("    \(path)")
            }
            
            print("=======================")
        }
        
        dispatch(workItem)
    }
}

// MARK: - internal

private extension Dispatcher {
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
    
    func request(
        joinOnly: Bool,
        inCurrentQueue: Bool,
        path: String,
        options: [String: Any]?,
        watcher: Watcher) {
        guard let handler = watcher.handler else {
            print("===== warning: handler is nil")
            return
        }
        
        let workItem = DispatchWorkItem { [unowned self] in
            if handler.delegate == nil {
                print("===== error: handler.delegate is nil")
                return
            }
            
            let genericPath = self.genericPath(with: path)
            var requestInfo: RequestInfo? = self.activeRequests[path]
            
            if joinOnly && requestInfo == nil { return }
            
            if requestInfo == nil {
                guard let actor = self.actor(genericPath, path: path) else {
                    print("===== error: actor not found for \"\(path)\"")
                    return
                }
                
                let watchers = [handler]
                requestInfo = (actor, watchers)
                self.activeRequests[path] = requestInfo
                
                actor.prepare(options: options)
                
                var executeNow = true
                if let requestQueueName = actor.requestQueueName {
                    var requestQueue = self.requestQueues[requestQueueName]
                    if requestQueue == nil {
                        requestQueue = [actor]
                    } else {
                        requestQueue!.append(actor)
                        if requestQueue!.count > 1 {
                            executeNow = false
                            print("===== adding request \(actor) to request queue \"\(requestQueueName)\"")
                        }
                    }
                    self.requestQueues[requestQueueName] = requestQueue
                }
                
                if executeNow {
                    actor.execute(options: options)
                } else {
                    actor.storedOptions = options
                }
            } else {
                if requestInfo!.watchers.contains(object: handler) {
                    print("===== joining watcher to the wathcers of \"\(path)\"")
                    requestInfo!.watchers.append(handler)
                    self.activeRequests[path] = requestInfo!
                } else {
                    print("===== continue to watch for actor \"\(path)\"")
                }
                
                if requestInfo!.requestActor.requestQueueName == nil {
                    requestInfo!.requestActor.watcherJoined(handler, options: options, waitingInActorQueue: false)
                } else {
                    let requestQueue = self.requestQueues[requestInfo!.requestActor.requestQueueName!]
                    if  requestQueue == nil || requestQueue?.count == 0 {
                        requestInfo!.requestActor.watcherJoined(handler, options: options, waitingInActorQueue: false)
                    } else {
                        let wait = (requestQueue?[0] !== requestInfo!.requestActor)
                        requestInfo!.requestActor.watcherJoined(handler, options: options, waitingInActorQueue: wait)
                    }
                }
            }
        }
        
        if inCurrentQueue {
            workItem.perform()
        } else {
            dispatch(workItem)
        }
    }
    
    func removeRequestAndExecuteNextIn(_ queueName: String, requestActor: SwiftActor) {
        var requestQueueName = requestActor.requestQueueName
        if requestQueueName == nil {
            requestQueueName = queueName
        }
        
        guard var requestQueue = requestQueues[requestQueueName!] else {
            print("===== warning: requestQueue is nil")
            return
        }
        
        if requestQueue.count == 0 {
            print("===== warning: request queue \"\(requestQueueName!) is empty.\"")
        } else {
            if requestQueue[0] === requestActor {
                requestQueue.remove(at: 0)
                
                if requestQueue.count != 0 {
                    let nextRequest = requestQueue[0]
                    let nextRequestOptions = nextRequest.storedOptions
                    nextRequest.storedOptions = nil
                    
                    if !nextRequest.isCancelled {
                        nextRequest.execute(options: nextRequestOptions)
                    }
                } else {
                    requestQueues.removeValue(forKey: requestQueueName!)
                }
            } else {
                if requestQueue.contains(object: requestActor) {
                    requestQueue.remove(object: requestActor)
                } else {
                    print("===== warning: request queue \"\(requestQueueName!)\" doesn't contain request to \(requestActor.path)")
                }
            }
        }
        
        requestQueues[requestQueueName!] = requestQueue
    }
    
    func cancelRequest(_ path: String) {
        guard let requestInfo = activeRequests[path] else {
            print("===== warning: cannot cancel request to \"\(path)\": no active request found")
            return
        }
        
        activeRequests.removeValue(forKey: path)
        
        requestInfo.requestActor.cancel()
        print("===== cancelled request to \"\(path)\"")
        
        guard let requestQueueName = requestInfo.requestActor.requestQueueName else {
            return
        }
        
        removeRequestAndExecuteNextIn(requestQueueName, requestActor: requestInfo.requestActor)
    }
    
    func actor(_ genericPath: String, path: String) -> SwiftActor? {
        guard let actorType = registeredActors[genericPath] else { return nil }
        return actorType.init(path: genericPath)
    }
}


private var registeredActors: [String: SwiftActor.Type] = [:]

// MARK: - default shared instance

public let Actor = Dispatcher.default
