//
//  Dispatcher.swift
//  SwiftActor
//
//  Created by Hanguang on 20/11/2017.
//  Copyright © 2017 Hanguang. All rights reserved.
//

import Foundation

// MARK: - default shared instance

public let Actor = Dispatcher.default

public final class Dispatcher {
    
    // MARK: - constants
    
    public static let `default` = Dispatcher()
    public let mainQueue: DispatchQueue!
    public let highPriorityQueue: DispatchQueue!
    public let globalQueue: DispatchQueue!
    public let networkQueue: DispatchQueue!
    
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
    
//    private let removeWatcherRequest: [()]
    
    
    
    private init() {
        queueSpecificKey = DispatchSpecificKey<String>()
        mainQueueKey = "com.hanguang.app.main"
        highPriorityQueueKey = mainQueueKey+"-high"
        globalQueueKey = mainQueueKey+"-global"
        networkQueueKey = mainQueueKey+"-network"
        
        mainQueue = DispatchQueue(label: mainQueueKey, qos: .utility, autoreleaseFrequency: .workItem)
        highPriorityQueue = DispatchQueue(label: highPriorityQueueKey, qos: .userInitiated, autoreleaseFrequency: .workItem, target: mainQueue)
        globalQueue = DispatchQueue(label: globalQueueKey, qos: .utility, autoreleaseFrequency: .workItem, target: mainQueue)
        networkQueue = DispatchQueue(label: networkQueueKey, qos: .utility, autoreleaseFrequency: .workItem, target: mainQueue)
        
        mainQueue.setSpecific(key: queueSpecificKey, value: mainQueueKey)
        highPriorityQueue.setSpecific(key: queueSpecificKey, value: highPriorityQueueKey)
        globalQueue.setSpecific(key: queueSpecificKey, value: globalQueueKey)
        networkQueue.setSpecific(key: queueSpecificKey, value: networkQueueKey)
    }
    
}

