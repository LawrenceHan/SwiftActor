//
//  TestViewController.swift
//  example
//
//  Created by Hanguang on 22/11/2017.
//  Copyright © 2017 Hanguang. All rights reserved.
//

import UIKit
import SwiftActor

class TestViewController: BaseViewController, Watcher {
    var handler: Handler?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        handler = Handler(self)
        Actor.watch("/alert", watcher: self)
    }
    
    @IBAction func showLog() {
        Actor.request("/alert", watcher: self)
    }
    
    func resourceDispatched(_ path: String, resource: Any, arg: Any?) {
        if path == "/alert" {
            DispatchOnMainQueue {
                print("===== \(String(describing: self)): \(String(describing: resource))")
            }
        }
    }
}
