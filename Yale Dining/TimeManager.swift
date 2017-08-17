//
//  TimeManager.swift
//  Yale
//
//  Created by Lee on 4/7/17.
//  Copyright © 2017 Yale STC Developers. All rights reserved.
//

/**
 * Any time you want to get the current date, do it through a time manager.
 * This allows tests to customize the dates received.
 * For example, Cache timeouts should be testable without actually
 * waiting for a cache to time-out.
 */

import UIKit

var defaultTimeManager: TimeManager = StandardTimeManager()

protocol TimeManager {
    func now() -> Date
}

class StandardTimeManager: NSObject, TimeManager {
    func now() -> Date {
        return Date()
    }
}
