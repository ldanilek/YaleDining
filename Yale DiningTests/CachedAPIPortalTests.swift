//
//  CachedAPIPortalTests.swift
//  Yale
//
//  Created by Lee on 3/21/17.
//  Copyright © 2017 Yale STC Developers. All rights reserved.
//

import XCTest
@testable import Yale_Dining

class CachedAPIPortalTests: XCTestCase {
    var network: NetworkManagerMock!
    var disk: DiskManagerMock!
    var time: TimeManagerMock!
    var keyValueStore: UserDefaults!
    let url = URL(string: "http://www.google.com")!
    let data = "ABC123DoReMi".data(using: String.Encoding.ascii)!
    let data2 = "AOEUHTNS123456789".data(using: .ascii)!
    var queue: DispatchQueue!
    let portal = CachedAPIPortal.default
    let docsDir = "/documents/"
    
    var cacheDir: String {
        return NSString(string: docsDir).appendingPathComponent("cached_api_responses")
    }
    
    var cachePath: URL {
        let escaped = NSString(string: url.absoluteString).addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics)!
        return URL(fileURLWithPath: NSString(string: cacheDir).appendingPathComponent(escaped))
    }
    
    var timeoutKey: String {
        return "Timeout date for URL: \(url)"
    }
    
    override func setUp() {
        network = NetworkManagerMock()
        portal.network = network
        disk = DiskManagerMock()
        portal.disk = disk
        time = TimeManagerMock()
        portal.time = time
        keyValueStore = UserDefaults()
        portal.keyValueStore = keyValueStore
        time.defaultDate = Date(timeIntervalSince1970: 0)
        portal.documentsDirectory = docsDir
        queue = DispatchQueue(label: "api_portal.test.sdmp.yale")
        expectCacheTimeoutQuery() // reset user defaults
        super.setUp()
    }
    
    // MARK: - Expect certain parts of the portal to operate as intended

    func networkExpect(url: URL, responseCode: Int, contentLength: Int?, disposition: URLSession.ResponseDisposition, dataChunks: [Data], error: Error?) {
        let response = HTTPURLResponse(url: url, statusCode: responseCode, httpVersion: nil, headerFields: contentLength==nil ? nil : ["Content-Length" : "\(contentLength!)"])!
        network.expect(forURL: url, response: response, disposition: disposition, expectDispo: self.expectedPromise(), dataChunks: dataChunks, error: error)
    }
    
    func expectNetworkSuccess() {
        networkExpect(url: url, responseCode: 200, contentLength: data.count, disposition: .allow, dataChunks: [data], error: nil)
    }
    
    // when the portal doesn't read or write to the cache, it tries to invalidate the cache
    // this involves finding the path where the file should exist and removing it
    func expectCacheInvalidation() {
        // in most common case remove will fail, because file doesn't exist
        disk.expect(method: .removeItem, args: [cachePath], andReturn: Promise<Void>(withQueue: queue) {
            return .Excuse(NSError(domain: "test.api-portal.sdmp.yale", code: 0, userInfo: nil))
        }, fulfill: expectedPromise(withName: "cache invalidation"))
    }
    
    // the portal always queries for the cached_api_responses directory
    // if it's not reading or writing to cache, it will try to invalidate the cache
    func expectDirQuery(result: (exists: Bool, isDir: Bool) = (exists: true, isDir: true)) {
        disk.expect(method: .fileExists, args: [cacheDir], andReturn: Promise(withQueue: queue) {
            return .Value(result)
        }, fulfill: expectedPromise(withName: "dir query"))
    }
    
    func expectCacheQuery(withResult result: PromiseResult<Data>? = nil) {
        disk.expect(method: .readData, args: [cachePath], andReturn: Promise(withQueue: queue) {
            return result ?? .Value(self.data)
        }, fulfill: expectedPromise(withName: "read data query"))
    }
    
    func expectCacheWrite(withResult result: PromiseResult<Void>? = nil) {
        disk.expect(method: .writeData, args: [data, cachePath], andReturn: Promise(withQueue: queue) {
            return result ?? .Value()
        }, fulfill: expectedPromise(withName: "write data"))
    }
    
    func expectCreateDirectory(withResult result: PromiseResult<Void>? = nil) {
        disk.expect(method: .createDirectory, args: [cacheDir], andReturn: Promise<Void>(withQueue: queue) {
            return result ?? .Value()
        }, fulfill: expectedPromise(withName: "create directory"))
    }
    
    // nil removes it from the key-value store
    func expectCacheTimeoutQuery(withStaleTime date: Date? = nil) {
        keyValueStore.set(date, forKey: timeoutKey)
    }
    
    // MARK: - Fetch
    
    /**
     * Fetch has many ways it can go right or wrong.
     * Test it separately from caching.
     */
    
    // tests successful network fetch of one data packet that isn't cached
    func testFetch() {
        expectNetworkSuccess()
        expectDirQuery()
        expectCacheInvalidation()
        expect(promise: portal.fetch(url: url, forceFetch: true), hasResult: data, withName: "expect data fetched")
        self.waitForExpectations(timeout: 1)
    }
    
    /**
     * Test that I'm never using the current queue when I shouldn't be
     * (if this fails but the previous test succeeds, it's a deadlock)
     */
    func testFetchSyncResult() {
        expectNetworkSuccess()
        expectDirQuery()
        expectCacheInvalidation()
        let result = portal.fetch(url: url, forceFetch: true)
        XCTAssertEqual(result.syncValue(), data)
        self.waitForExpectations(timeout: 1)
    }
    
    func testFetchBadStatus() {
        networkExpect(url: url, responseCode: 500, contentLength: nil, disposition: .cancel, dataChunks: [], error: nil)
        // it would cache but can't so it invalidates the cache
        let result = portal.fetch(url: url, cacheTTL: 100, forceFetch: true)
        let expectExcuse = self.expectation(description: "expect it to fail")
        result.onRenege(withQueue: queue, { err in
            XCTAssertEqual((err as NSError).code, 500)
            expectExcuse.fulfill()
        }).onProgress(withQueue: queue, { (_, _) in
            XCTFail()
        }).onKeep(withQueue: queue) { _ in
            XCTFail()
        }
        
        self.waitForExpectations(timeout: 1)
    }
    
    func testFetchError() {
        networkExpect(url: url, responseCode: 200, contentLength: nil, disposition: .allow, dataChunks: [], error: NSError(domain: "domain", code: 123, userInfo: nil))
        let result = portal.fetch(url: url, cacheTTL: 100, forceFetch: true)
        XCTAssertEqual((result.syncExcuse()! as NSError).code, 123)
        self.waitForExpectations(timeout: 1)
    }
    
    // test concatenation when fetch returns multiple data pieces
    func testFetchDataChunks() {
        networkExpect(url: url, responseCode: 200, contentLength: data.count+data2.count, disposition: .allow, dataChunks: [data, data2], error: nil)
        expectDirQuery()
        expectCacheInvalidation()
        expect(promise: portal.fetch(url: url, forceFetch: true), hasResult: self.data+self.data2, withName: "should get all data")
        self.waitForExpectations(timeout: 1)
    }
    
    func testFetchDataProgress() {
        let allData = data + data2
        networkExpect(url: url, responseCode: 200, contentLength: allData.count, disposition: .allow, dataChunks: [data, data2], error: nil)
        expectDirQuery()
        expectCacheInvalidation()
        let expectNone = self.expectation(description: "should get progress of 0 first")
        let expectPartial = self.expectation(description: "should get partial data next")
        let expectFull = self.expectation(description: "should get all data")
        var prevValue = -1 // must be increasing
        portal.fetch(url: url, forceFetch: true).onProgress(withQueue: queue) { (partial, of) in
            XCTAssertEqual(of, allData.count)
            XCTAssertGreaterThan(partial, prevValue)
            prevValue = partial
            if partial == 0 {
                expectNone.fulfill()
            } else if partial == self.data.count {
                expectPartial.fulfill()
            } else if partial == allData.count {
                expectFull.fulfill()
            } else {
                XCTFail()
            }
        }
        self.waitForExpectations(timeout: 1)
    }
    
    // should be able to handle network requests with no content length
    func testFetchNoLength() {
        networkExpect(url: url, responseCode: 200, contentLength: nil, disposition: .allow, dataChunks: [data], error: nil)
        expectDirQuery()
        expectCacheInvalidation()
        let expectNone = self.expectation(description: "should be notified of 0")
        let expectFull = self.expectation(description: "should be notified of full")
        let expectData = self.expectation(description: "should receive data")
        var prevValue = -1
        portal.fetch(url: url, forceFetch: true).onProgress(withQueue: queue, { (partial, of) in
            XCTAssertEqual(of, -1) // technical detail of URLResponse, when no content length is provided, it's -1
            XCTAssertGreaterThan(partial, prevValue)
            prevValue = partial
            if partial == 0 {
                expectNone.fulfill()
            } else if partial == self.data.count {
                expectFull.fulfill()
            } else {
                XCTFail()
            }
        }).onKeep(withQueue: queue, { value in
            XCTAssertEqual(value, self.data)
            expectData.fulfill()
        })
        self.waitForExpectations(timeout: 1)
    }
    
    // MARK: - Read Cache
    
    /**
     * Begin tests for reading from cache.
     * First of all, it can fail in many ways.
     * In all cases, it should fall-back to a fetch
     */
    
    func assertCacheReadFailureRecovered() {
        // fetch should be successful
        expectNetworkSuccess()
        // writing to cache should be an invalidation
        expectDirQuery()
        expectCacheInvalidation()
        let foundData = portal.fetch(url: url).syncValue(timeout: 1)
        XCTAssertEqual(foundData, data)
        self.waitForExpectations(timeout: 1)
    }
    
    // if the directory for the cache exists as a file
    func testDirIsFileFailure() {
        // not stale, tries to read from cache, but can't access directory
        expectCacheTimeoutQuery(withStaleTime: time.defaultDate.addingTimeInterval(10))
        expectDirQuery(result: (exists: true, isDir: false))
        assertCacheReadFailureRecovered()
    }
    
    // if dir doesn't exist, try to create it
    func testDirCreation() {
        expectCacheTimeoutQuery(withStaleTime: time.defaultDate.addingTimeInterval(10))
        expectDirQuery(result: (exists: false, isDir: false))
        expectCreateDirectory()
        // if dir creation succeeds, it should query the cache
        expectCacheTimeoutQuery(withStaleTime: Date.distantFuture)
        expectCacheQuery()
        // cache read is success, so this is just like testReadCache
        let foundData = portal.fetch(url: url).syncValue(timeout: 1)
        XCTAssertEqual(foundData, data)
        self.waitForExpectations(timeout: 1)
    }
    
    func testDirCreationFailure() {
        expectCacheTimeoutQuery(withStaleTime: time.defaultDate.addingTimeInterval(10))
        expectDirQuery(result: (exists: false, isDir: false))
        expectCreateDirectory(withResult: .Excuse(NSError(domain: "test.api-portal.sdmp.yale", code: 0, userInfo: nil)))
        assertCacheReadFailureRecovered()
    }
    
    func testStaleCache() {
        expectCacheTimeoutQuery(withStaleTime: time.defaultDate.addingTimeInterval(-10))
        assertCacheReadFailureRecovered()
    }
    
    func testNoCache() {
        expectCacheTimeoutQuery(withStaleTime: nil)
        assertCacheReadFailureRecovered()
    }
    
    func testReadCacheFailure() {
        expectCacheTimeoutQuery(withStaleTime: time.defaultDate.addingTimeInterval(10))
        expectDirQuery()
        expectCacheQuery(withResult: .Excuse(NSError(domain: "test.api-portal.sdmp.yale", code: 0, userInfo: nil)))
        assertCacheReadFailureRecovered()
    }
    
    func testReadCache() {
        // expect no network request
        // first checks if cache directory
        expectCacheTimeoutQuery(withStaleTime: time.defaultDate.addingTimeInterval(10))
        expectDirQuery()
        expectCacheQuery()
        let foundData = portal.fetch(url: url).syncValue()
        XCTAssertEqual(foundData, self.data)
        self.waitForExpectations(timeout: 1)
    }
    
    // MARK: - Write Cache
    
    /**
     * Writing to cache is mostly independent of reading,
     * so we can test them separately.
     */
    
    func testWriteCache() {
        expectNetworkSuccess()
        expectDirQuery()
        expectCacheWrite()
        expect(promise: portal.fetch(url: url, cacheTTL: 10, forceFetch: true), hasResult: data, withName: "expect data fetched")
        self.waitForExpectations(timeout: 1)
        let newTimeout = keyValueStore.value(forKey: timeoutKey) as! Date
        XCTAssertEqual(newTimeout.timeIntervalSince1970, 10)
    }
    
    func testWriteFailure() {
        expectNetworkSuccess()
        expectDirQuery()
        expectCacheWrite(withResult: .Excuse(NSError(domain: "write.api-portal.sdmp.yale", code: 0, userInfo: nil)))
        // cache write failure doesn't affect what data is returned
        expect(promise: portal.fetch(url: url, cacheTTL: 10, forceFetch: true), hasResult: data, withName: "expect data fetched")
        self.waitForExpectations(timeout: 1)
        XCTAssertNil(keyValueStore.value(forKey: timeoutKey))
    }
    
    func testDirCreationOnWrite() {
        expectNetworkSuccess()
        expectDirQuery(result: (exists: false, isDir: false))
        expectCreateDirectory()
        expectCacheWrite()
        expect(promise: portal.fetch(url: url, cacheTTL: 10, forceFetch: true), hasResult: data, withName: "expect data fetched")
        self.waitForExpectations(timeout: 1)
        let newTimeout = keyValueStore.value(forKey: timeoutKey) as! Date
        XCTAssertEqual(newTimeout.timeIntervalSince1970, 10)
    }
    
    // if directory can't be created, don't even try to write
    func testDirCreationOnWriteFailure() {
        expectNetworkSuccess()
        expectDirQuery(result: (exists: false, isDir: false))
        expectCreateDirectory(withResult: .Excuse(NSError(domain: "test.api-portal.sdmp.yale", code: 0, userInfo: nil)))
        expect(promise: portal.fetch(url: url, cacheTTL: 10, forceFetch: true), hasResult: data, withName: "expect data fetched")
        self.waitForExpectations(timeout: 1)
        XCTAssertNil(keyValueStore.value(forKey: timeoutKey))
    }
    
    // assuming cached object exists but is stale
    // this is probably one of the most common things that will happen
    func testEndToEndFetchSuccess() {
        expectCacheTimeoutQuery(withStaleTime: time.defaultDate.addingTimeInterval(-10))
        expectNetworkSuccess()
        expectDirQuery()
        expectCacheWrite()
        expect(promise: portal.fetch(url: url, cacheTTL: 10, forceFetch: false), hasResult: data, withName: "expect data fetched")
        self.waitForExpectations(timeout: 1)
        let newTimeout = keyValueStore.value(forKey: timeoutKey) as! Date
        XCTAssertEqual(newTimeout.timeIntervalSince1970, 10)
    }
}
