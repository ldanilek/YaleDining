//
//  TimeManagerMock.swift
//  Yale
//
//  Created by Lee on 4/7/17.
//  Copyright © 2017 Yale STC Developers. All rights reserved.
//

import UIKit

class TimeManagerMock: NSObject, TimeManager {
    public var timesChange = [Date]()
    public var defaultDate = Date()
    func now() -> Date {
        if timesChange.isEmpty {
            return defaultDate
        }
        return timesChange.removeFirst()
    }
}
