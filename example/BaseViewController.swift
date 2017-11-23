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
        
        Actor.remove(watcher: self)
        print("===== \(self) deinited")
    }
}
