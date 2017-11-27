//
//  ViewController.swift
//  example
//
//  Created by Hanguang on 20/11/2017.
//  Copyright © 2017 Hanguang. All rights reserved.
//

import UIKit
import SwiftActor

class ViewController: BaseViewController {
//    var handler: Handler?
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        handler = Handler(self)
        ActorDispatcher.register(TestActor.self)
        ActorDispatcher.watch("/alert", watcher: self)
    }

    deinit {
        handler?.reset()
        ActorDispatcher.remove(watcher: self)
    }
    
    @IBAction func showLog() {
        ActorDispatcher.request("/alert", watcher: self)
    }
    
    @IBAction func showTestVC() {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        let vc = sb.instantiateViewController(withIdentifier: "TestViewController")
        navigationController?.pushViewController(vc, animated: true)
    }
    
    override func resourceDispatched(_ path: String, resource: Any, arg: Any?) {
        if path == "/alert" {
            DispatchOnMainQueue {
                print("===== \(String(describing: self)): \(String(describing: resource))")
            }
        }
    }
}

