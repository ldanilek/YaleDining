//
//  NetworkIntegrationTests.swift
//  Yale
//
//  Created by Lee on 2/24/17.
//  Copyright © 2017 Yale STC Developers. All rights reserved.
//

import UIKit
import XCTest
@testable import Yale_Dining

/**
 Mocks the file system caching layer. Does NOT mock the network interactions.
 This is therefore an integration test for interface between CachedAPIPortal and URLSession.
 It can also be used to find performance metrics for the APIs themselves.
 */
class NetworkIntegrationTests: XCTestCase {
    let portal = CachedAPIPortal.default
    var disk: DiskManagerMock!
    override func setUp() {
        portal.network = StandardNetworkManager()
        disk = DiskManagerMock()
        portal.disk = disk
        portal.documentsDirectory = "/documents/"
        portal.keyValueStore = UserDefaults.standard
        portal.time = StandardTimeManager()

        CachedAPIPortal.default.network = StandardNetworkManager()
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    let locationsURL = URL(string: "http://www.yaledining.org/fasttrack/locations.cfm?version=3")!
    
    var cachePath: URL {
        let escaped = NSString(string: locationsURL.absoluteString).addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics)!
        return URL(fileURLWithPath: NSString(string: "/documents/cached_api_responses").appendingPathComponent(escaped))
    }
    
    func testEventsPerformance() {
        // This is an example of a performance test case.
        self.measure {
            let expected = self.expectation(description: "Want the events API to return something.")

            let queue = DispatchQueue(label: "network.tests.sdmp.yale")
            self.disk.expect(method: .fileExists, args: ["/documents/cached_api_responses"], andReturn: Promise(withQueue: queue) {
                return .Value((exists: true, isDir: true))
            }, fulfill: self.expectedPromise(withName: "file exists"))
            self.disk.expect(method: .removeItem, args: [self.cachePath], andReturn: Promise(withQueue: queue) {
                return .Value()
            }, fulfill: self.expectedPromise(withName: "remove"))
            CachedAPIPortal.default.fetch(url: self.locationsURL,
                                          forceFetch: true).onKeep(withQueue: queue, { data in
                                            print("Received \(data.count) bytes from events API")
                                            expected.fulfill()
                                          }).onRenege(withQueue: DispatchQueue.main, { (err) in
                                            print("Failed with error: \(err)")
                                            XCTFail()
                                          })
            self.waitForExpectations(timeout: 10, handler: nil)
        }
    }
}
