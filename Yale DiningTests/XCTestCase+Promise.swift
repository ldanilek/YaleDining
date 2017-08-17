//
//  XCTestCase+Promise.swift
//  Yale
//
//  Created by Lee on 4/16/17.
//  Copyright © 2017 Yale STC Developers. All rights reserved.
//

import XCTest
@testable import Yale_Dining

private let backgroundQueue = DispatchQueue(label: "promise.test.sdmp.yale")

// MARK: Promise
extension XCTestCase {
    // returns a promise that is expected to be kept
    func expectedPromise(withName name: String = "expected promise") -> Promise<Void> {
        let expect = self.expectation(description: name)
        let promise = Promise<Void>(withQueue: backgroundQueue)
        promise.onKeep {
            expect.fulfill()
        }
        return promise
    }
    
    func expect<T: Equatable>(promise: Promise<T>, hasResult result: T, withName name: String = "expected promise") {
        let expect = self.expectation(description: name)
        promise.onKeep(withQueue: backgroundQueue) { val in
            XCTAssertEqual(result, val)
            expect.fulfill()
        }
    }
}
