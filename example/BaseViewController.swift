//
//  BaseViewController.swift
//  example
//
//  Created by Hanguang on 22/11/2017.
//  Copyright © 2017 Hanguang. All rights reserved.
//

import UIKit
import SwiftActor

class BaseViewController: UIViewController, Watcher {
    var handler: Handler?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        handler = Handler(self)
    }
    
    deinit {
        handler?.reset()
        ActorDispatcher.remove(watcher: self)
        print("===== \(self) deinited")
    }
    
    func reportedProgress(_ path: String, progress: CGFloat) {}
    func resourceDispatched(_ path: String, resource: Any, arg: Any?) {}
    func completed(_ path: String, result: SwiftActor.Result) {}
    func requested(_ action: String, options: [String : Any]?) {}
    func watcherMessageReceived(_ path: String, messageType: String?, message: Any?) {}
    func actorMessageReceived(_ path: String, messageType: String?, message: Any?) {}
}
