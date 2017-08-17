//
//  TimeManagerMockTests.swift
//  Yale
//
//  Created by Lee on 4/7/17.
//  Copyright © 2017 Yale STC Developers. All rights reserved.
//

import XCTest
@testable import Yale_Dining

class TimeManagerMockTests: XCTestCase {
    let time = TimeManagerMock()
    
    func testDefaultDate() {
        time.defaultDate = Date.init(timeIntervalSince1970: 100)
        XCTAssertEqual(time.now().timeIntervalSince1970, 100)
    }
    
    func testChangingDate() {
        time.timesChange = [Date(timeIntervalSince1970: 10), Date(timeIntervalSince1970: 20)]
        XCTAssertEqual(time.now().timeIntervalSince1970, 10)
        XCTAssertEqual(time.now().timeIntervalSince1970, 20)
    }
    
    func testChangeThenDefault() {
        time.defaultDate = Date(timeIntervalSince1970: 30)
        time.timesChange = [Date(timeIntervalSince1970: 40)]
        XCTAssertEqual(time.now().timeIntervalSince1970, 40)
        XCTAssertEqual(time.now().timeIntervalSince1970, 30)
    }
}
