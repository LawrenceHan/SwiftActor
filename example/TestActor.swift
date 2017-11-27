//
//  TestActor.swift
//  example
//
//  Created by Hanguang on 22/11/2017.
//  Copyright © 2017 Hanguang. All rights reserved.
//

import SwiftActor

class TestActor: Actor {
    override class var genericPath: String {
        return "/alert"
    }
    
    override func execute(options: [String : Any]?) {
        ActorDispatcher.dispatch(path, resource: "Good")
        ActorDispatcher.completed(path, result: .success(nil))
    }
}
