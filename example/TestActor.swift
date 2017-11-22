//
//  TestActor.swift
//  example
//
//  Created by Hanguang on 22/11/2017.
//  Copyright © 2017 Hanguang. All rights reserved.
//

import SwiftActor

class TestActor: SwiftActor {
    override class var genericPath: String {
        return "/alert"
    }
    
    override func execute(options: [String : Any]?) {
        Actor.dispatch(path, resource: "Good")
        Actor.completed(path, result: .success(nil))
    }
}
