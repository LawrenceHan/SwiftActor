//
//  ViewController.swift
//  example
//
//  Created by Hanguang on 20/11/2017.
//  Copyright © 2017 Hanguang. All rights reserved.
//

import UIKit
import SwiftActor

class ViewController: BaseViewController, Watcher {
    var handler: Handler?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Actor.register(TestActor.self)
        
        handler = Handler(self)
        Actor.watch("/alert", watcher: self)
    }

    @IBAction func showLog() {
        Actor.request("/alert", watcher: self)
    }
    
    @IBAction func showTestVC() {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        let vc = sb.instantiateViewController(withIdentifier: "TestViewController")
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func resourceDispatched(_ path: String, resource: Any, arg: Any?) {
        if path == "/alert" {
            DispatchOnMainQueue {
                print("===== \(String(describing: self)): \(String(describing: resource))")
            }
        }
    }
}

