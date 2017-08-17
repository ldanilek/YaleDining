//
//  CachedAPIPortalMockTests.swift
//  Yale
//
//  Created by Lee on 3/24/17.
//  Copyright © 2017 Yale STC Developers. All rights reserved.
//

import XCTest
@testable import Yale_Dining

class CachedAPIPortalMockTests: XCTestCase {
    let url = URL(string: "http://www.google.com")!
    let data = "API returned data".data(using: .ascii)!
    let error = NSError(domain: "test.mock.api_portal.sdmp.yale", code: 0, userInfo: nil)
    let mock = CachedAPIPortalMock()
    let bgQueue = DispatchQueue(label: "test.mock.api_portal.sdmp.yale")
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSuccess() {
        let promise = Promise<Data>(withQueue: bgQueue)
        mock.expect(url: url, andReturn: promise)
        let expectSuccess = self.expectation(description: "Should succeed")
        mock.fetch(url: url).onKeep(withQueue: bgQueue) { value in
            XCTAssertEqual(value, self.data)
            expectSuccess.fulfill()
        }
        promise.keep(withValue: data)
        self.waitForExpectations(timeout: 1)
    }
    
    func testFailure() {
        let promise = Promise<Data>(withQueue: bgQueue)
        mock.expect(url: url, andReturn: promise)
        let expectFailure = self.expectation(description: "Should fail")
        mock.fetch(url: url).onRenege(withQueue: bgQueue) { err in
            XCTAssertEqual(err as NSError, self.error)
            expectFailure.fulfill()
        }
        promise.renege(withExcuse: error)
        self.waitForExpectations(timeout: 1)
    }
    
    /**
     * Returned promise should be exactly the one specified
     */
    func testPromiseEquality() {
        let promise = Promise<Data>()
        mock.expect(url: url, andReturn: promise)
        XCTAssertEqual(mock.fetch(url: url), promise)
    }
    
    /**
     * Can expect multiple things and receive them multiple times and in any order.
     */
    func testMultiple() {
        let promise = Promise<Data>()
        let promise2 = Promise<Data>()
        let promise3 = Promise<Data>()
        let url2 = URL(string: "http://www.yale.edu")!
        mock.expect(url: url, andReturn: promise)
        mock.expect(url: url, cacheTTL: 100, forceFetch: true, andReturn: promise2)
        mock.expect(url: url2, cacheTTL: 50, andReturn: promise3)
        
        XCTAssertEqual(mock.fetch(url: url), promise)
        XCTAssertEqual(mock.fetch(url: url, cacheTTL: 100, forceFetch: true), promise2)
        XCTAssertEqual(mock.fetch(url: url2, cacheTTL: 50), promise3)
        XCTAssertEqual(mock.fetch(url: url), promise)
    }
    
    /**
     * Expectations can be overridden.
     */
    func testOverride() {
        let promise = Promise<Data>()
        let promise2 = Promise<Data>()
        mock.expect(url: url, andReturn: promise)
        mock.expect(url: url, andReturn: promise2)
        XCTAssertEqual(mock.fetch(url: url), promise2)
    }
}
