//
//  PromiseTests.swift
//  Yale
//
//  Created by Lee on 3/18/17.
//  Copyright © 2017 Yale STC Developers. All rights reserved.
//

import XCTest
@testable import Yale_Dining

let PromiseTestErrorCode = 123

class PromiseTests: XCTestCase {
    // promises need a background queue to do operations.
    // don't want to wait for the promise on the same queue it will be fulfilled on,
    // to avoid deadlock. When actually using promises, callbacks on the main and
    // current queues should be fine, because they will rarely be blocked.
    let bgQueue = DispatchQueue(label: "promise.sdmp.yale")
    
    // waits for all currently executing tasks to finish
    private func sync() {
        bgQueue.sync {
            // this should make the bgQueue caught up.
        }
    }
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // simple test to see that a successful promise result calls the completion handler
    func testSuccess() {
        let promise = Promise<String>(withQueue: bgQueue)
        let expectSuccess = self.expectation(description: "promise should call success handler")
        promise.onKeep { string in
            XCTAssertEqual(string, "test string", "fulfill block should provide data")
            expectSuccess.fulfill()
        }
        promise.keep(withValue: "test string")
        self.waitForExpectations(timeout: 1)
    }
    
    func testFailure() {
        let promise = Promise<String>(withQueue: bgQueue)
        let expectFailure = self.expectation(description: "promise should call failure handler")
        promise.onRenege { error in
            XCTAssertEqual((error as NSError).code, PromiseTestErrorCode, "error codes should match")
            expectFailure.fulfill()
        }
        promise.renege(withExcuse: NSError(domain: "domain", code: PromiseTestErrorCode, userInfo: nil))
        self.waitForExpectations(timeout: 1)
    }
    
    func testCatchFailure() {
        let promise = Promise<String>(withQueue: bgQueue)
        let expectFailure = self.expectation(description: "promise should call failure handler")
        promise.onKeep({ value in
            // throws error in fulfill completion handler
            throw NSError(domain: "domain", code: PromiseTestErrorCode, userInfo: nil)
        }).onRenege { error in
            XCTAssertEqual((error as NSError).code, PromiseTestErrorCode, "error codes should match")
            expectFailure.fulfill()
        }
        promise.keep(withValue: "Corrupted data")
        self.waitForExpectations(timeout: 1)
    }
    
    func testChaining() {
        let promise = Promise<String>(withQueue: bgQueue)
        let expectSuccess = self.expectation(description: "promise should succeed")
        let expectSuccess2 = self.expectation(description: "child promise should succeed")
        let expectFailure = self.expectation(description: "grandchild promise should fail")
        promise.onKeep({ (string)->PromiseResult<String> in
            XCTAssertEqual(string, "success input")
            expectSuccess.fulfill()
            return .Value("success output")
        }).onKeep({ (string)->PromiseResult<String> in
            XCTAssertEqual(string, "success output")
            expectSuccess2.fulfill()
            return .Excuse(NSError(domain: "domain", code: PromiseTestErrorCode, userInfo: nil))
        }).onRenege({ error in
            XCTAssertEqual((error as NSError).code, PromiseTestErrorCode)
            expectFailure.fulfill()
        })
        promise.keep(withValue: "success input")
        self.waitForExpectations(timeout: 1)
    }
    
    func testFallthrough() {
        let promise = Promise<String>(withQueue: bgQueue)
        let expectFailure = self.expectation(description: "promise should detect failure")
        promise.onKeep({ string in
            XCTFail()
        }).onRenege({ error in
            XCTAssertEqual((error as NSError).code, PromiseTestErrorCode)
            expectFailure.fulfill()
        })
        promise.renege(withExcuse: NSError(domain: "domain", code: PromiseTestErrorCode, userInfo: nil))
        self.waitForExpectations(timeout: 1)
    }
    
    func testInstantFulfill() {
        let promise = Promise<String>(withQueue: bgQueue)
        promise.keep(withValue: "value")
        // wait for it to be actually fulfilled
        _ = promise.syncValue()
        // the point is that adding the completion handler fulfills the expectation immediately
        // you can't actually expect it to be synchronous, however, because it involves asynchronous queue dispatches
        let expectSuccess = self.expectation(description: "wait for success")
        promise.onKeep { string in
            XCTAssertEqual(string, "value")
            expectSuccess.fulfill()
        }
        self.waitForExpectations(timeout: 1)
    }
    
    func testPostpone() {
        let promise = Promise<String>(withQueue: bgQueue)
        let expectSuccess = self.expectation(description: "should be successfully fulfilled")
        promise.onKeep { string in
            XCTAssertEqual(string, "final data")
            expectSuccess.fulfill()
        }
        let prereqPromise = Promise<String>(withQueue: bgQueue)
        promise.postpone(withPromise: prereqPromise)
        sync()
        prereqPromise.keep(withValue: "final data")
        self.waitForExpectations(timeout: 1)
    }
    
    // if the postponing promise is kept before calling postpone, code
    // takes a different path but result should be the same
    func testInstantPostpone() {
        let promise = Promise<String>(withQueue: bgQueue)
        let expectSuccess = self.expectation(description: "should be successfully kept")
        promise.onKeep { string in
            XCTAssertEqual(string, "final data")
            expectSuccess.fulfill()
        }
        let prereqPromise = Promise<String>(withQueue: bgQueue)
        prereqPromise.keep(withValue: "final data")
        _ = prereqPromise.syncValue()
        promise.postpone(withPromise: prereqPromise)
        self.waitForExpectations(timeout: 1)
    }
    
    func testEmbeddedPostpone() {
        // e.g. cached data retrieval from disk
        let promise = Promise<String>(withQueue: bgQueue)
        let expectInitialRenege = self.expectation(description: "initial promise should be reneged upon")
        // e.g. API fetch following failed data retrieval
        let lazyPromise = Promise<String>()
        let child = promise.onRenege { (excuse)->PromiseResult<String> in
            XCTAssertEqual((excuse as NSError).code, PromiseTestErrorCode)
            expectInitialRenege.fulfill()
            // start API fetch here
            return .Promise(lazyPromise)
        }
        promise.renege(withExcuse: NSError(domain: "domain", code: PromiseTestErrorCode, userInfo: nil))
        self.waitForExpectations(timeout: 1)
        
        let expectSuccess = self.expectation(description: "lazy promise should succeed")
        child.onKeep { string in
            XCTAssertEqual(string, "data")
            expectSuccess.fulfill()
        }
        
        lazyPromise.keep(withValue: "data")
        self.waitForExpectations(timeout: 1)
    }
    
    func testProgress() {
        let promise = Promise<String>(withQueue: bgQueue)
        let expectHalf = self.expectation(description: "should get progress report for half")
        let expectFull = self.expectation(description: "should get progress report for full")
        let expectSuccess = self.expectation(description: "should get success report")
        promise.onProgress({ (partial, of)->PromiseResult<String> in
            XCTAssertEqual(of, 100, "denominator should be 100")
            if partial == 50 {
                expectHalf.fulfill()
            } else if partial == 100 {
                expectFull.fulfill()
                return .Value("100% delivered")
            } else {
                XCTFail()
            }
            return .Progress(partial, of)
        }).onKeep { string in
            XCTAssertEqual("100% delivered", string)
            expectSuccess.fulfill()
        }
        promise.reportProgress(partial: 50, of: 100)
        promise.reportProgress(partial: 100, of: 100)
        self.waitForExpectations(timeout: 1)
    }
    
    func testSyncValue() {
        let promise = Promise<String>(withQueue: bgQueue)
        promise.keep(withValue: "hello")
        let result = promise.syncValue()
        XCTAssertEqual(result, "hello", "Sync Value should return the correct value")
    }
    
    func testSyncError() {
        let promise = Promise<String>(withQueue: bgQueue)
        let error = NSError(domain: "domain", code: PromiseTestErrorCode, userInfo: nil)
        promise.renege(withExcuse: error)
        let result = promise.syncExcuse() as NSError?
        XCTAssertEqual(error, result, "Sync Error should return the correct value")
    }
    
    /**
     * Sync result should wait for callbacks.
     */
    func testSyncResultError() {
        let promise = Promise<String>(withQueue: bgQueue)
        let error = NSError(domain: "domain", code: PromiseTestErrorCode, userInfo: nil)
        let child = promise.onKeep { (value)->PromiseResult<Int> in
            return .Excuse(error)
        }
        promise.keep(withValue: "hello")
        let (result, err) = child.syncResult()
        XCTAssertNil(result)
        XCTAssertEqual(err as NSError?, error, "Sync Error should return the correct value")
    }
    
    func testSyncResultValue() {
        let promise = Promise<Int>(withQueue: bgQueue)
        let error = NSError(domain: "domain", code: PromiseTestErrorCode, userInfo: nil)
        let child = promise.onRenege(withQueue: bgQueue) { (err)->PromiseResult<String> in
            return .Value("result")
        }
        promise.renege(withExcuse: error)
        let (result, err) = child.syncResult()
        XCTAssertNil(err)
        XCTAssertEqual(result, "result", "Sync Value should return the correct value")
    }
    
    /**
     * Sample design for chained data transformation.
     * Besides sample code, this serves as an end-to-end test for a common use case of promises.
     */
    func testChainingTypes() {
        let dictionary = NSDictionary(dictionary: [NSString(string: "key1") : NSString(string: "value"),
                                                   NSString(string: "key2") : NSString(string: "value2")])
        
        let expectDeserialized = self.expectation(description: "expect deserialized")
        
        // also test using lots of different queues
        let deserializationQueue = DispatchQueue(label: "deserialization")
        let dictConversionQueue = DispatchQueue(label: "dict conversion")
        let hashQueue = DispatchQueue(label: "dict-hashing")
        let successQueue = DispatchQueue(label: "successful-queue")
        let failureQueue = DispatchQueue(label: "failure-queue")
        
        // e.g. returned from library API call
        let promise = Promise<Data>(withQueue: bgQueue)
        promise.onKeep(withQueue: deserializationQueue, { (data)->PromiseResult<Any> in
            return .Value(try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments))
        }).onKeep(withQueue: dictConversionQueue, { (object)->PromiseResult<NSDictionary> in
            if let dict = object as? NSDictionary {
                XCTAssert(dictionary.isEqual(to: dict as! [AnyHashable: Any]))
                return .Value(dict)
            }
            return .Excuse(NSError(domain: "domain", code: PromiseTestErrorCode, userInfo: nil))
        }).onKeep(withQueue: hashQueue, { (dict)->PromiseResult<Int> in
            return .Value(dict.hash)
        }).onKeep(withQueue: successQueue, { hash in
            XCTAssertEqual(hash, dictionary.hash)
            expectDeserialized.fulfill()
        }).onRenege(withQueue: failureQueue) { error in
            // errors (including the error thrown by deserializing) would end up here.
            XCTFail()
        }
        sync()
        
        // asynchronous data retrieval
        bgQueue.async {
            let data = try! JSONSerialization.data(withJSONObject: dictionary, options: .prettyPrinted)
            // e.g. Called in library function on data retrival success
            promise.keep(withValue: data)
        }
        
        self.waitForExpectations(timeout: 1)
    }
    
    /**
     * Chaining cannot channel through types that don't allow for conversion.
     */
    func testConversionFailure() {
        let promise = Promise<String>(withQueue: bgQueue)
        let expectation = self.expectation(description: "automatic conversion String to Int should fail")
        promise.onRenege({ (err)->PromiseResult<Int> in
            XCTFail()
            return .Excuse(err)
        }).onKeep({ value in
            XCTFail()
        }).onRenege({ err in
            XCTAssertEqual((err as NSError).domain, PromiseErrorDomain)
            expectation.fulfill()
        })
        promise.keep(withValue: "hi")
        self.waitForExpectations(timeout: 1)
    }
    
    /**
     * Chaining can channel if you can implicitly convert them
     */
    func testConversionSuccess() {
        let promise = Promise<String>(withQueue: bgQueue)
        let expectString = self.expectation(description: "automatic conversion from String to itself should succeed")
        let expectAny = self.expectation(description: "automatic conversion from String to Any should succeed")
        
        // don't want renege blocks to get in the way of fallthrough
        promise.onRenege({ err in
            XCTFail()
        }).onKeep({ value in
            expectString.fulfill()
            XCTAssertEqual(value, "hello")
        }).onRenege({ (err)->PromiseResult<Any> in
            // even with implicit downcast of values
            XCTFail()
            return .Excuse(err)
        }).onKeep({ value in
            expectAny.fulfill()
            XCTAssertEqual(value as! String, "hello")
        })
        promise.keep(withValue: "hello")
        self.waitForExpectations(timeout: 1)
    }
    
    /**
     * Tests multiple callbacks on the same promise.
     */
    func testMultipleCallbacks() {
        let promise = Promise<String>(withQueue: bgQueue)
        let expectCallback1 = self.expectation(description: "callback 1 should be called")
        let expectCallback2 = self.expectation(description: "callback 2 should be called")
        promise.onKeep({ (value)->PromiseResult<String> in
            XCTAssertEqual(value, "data")
            expectCallback1.fulfill()
            return .Value("string that must not be named")
        })
        promise.onKeep({ (value)->PromiseResult<String> in
            XCTAssertEqual(value, "data")
            expectCallback2.fulfill()
            return .Value("don't go there")
        })
        promise.keep(withValue: "data")
        self.waitForExpectations(timeout: 1)
    }
    
    /**
     * Consider making this undefined behavior.
     * For now, this is a supported use case of promises.
     */
    func testMultipleCompletions() {
        let promise = Promise<String>(withQueue: bgQueue)
        let expectSuccess = self.expectation(description: "promise should detect success")
        let expectFailure = self.expectation(description: "promise should detect failure")
        promise.onKeep({ string in
            XCTAssertEqual(string, "data")
            expectSuccess.fulfill()
        }).onRenege({ error in
            XCTAssertEqual((error as NSError).code, PromiseTestErrorCode)
            expectFailure.fulfill()
        })
        promise.renege(withExcuse: NSError(domain: "domain", code: PromiseTestErrorCode, userInfo: nil))
        promise.keep(withValue: "data")
        self.waitForExpectations(timeout: 1)
    }
    
    /**
     * Demonstration of the syntax when using degenerate promises: Promise<Void>
     */
    func testDegeneratePromise() {
        let promise = Promise<Void>(withQueue: bgQueue)
        let expectNotification = self.expectation(description: "expect the degenerate promise to succeed")
        promise.onKeep {
            expectNotification.fulfill()
        }
        promise.keep(withValue: ())
        self.waitForExpectations(timeout: 1)
    }
    
    // MARK: - Convenience initializer
    /**
     * Test the convenience initializer which creates a promise given a block.
     */
    func testInitWithResult() {
        let promise = Promise(withQueue: bgQueue) {
            return .Value("hello")
        }
        let expectResult = self.expectation(description: "expect the promise to already have a result")
        promise.onKeep { value in
            XCTAssertEqual("hello", value)
            expectResult.fulfill()
        }
        self.waitForExpectations(timeout: 1)
    }
    
    func testCatchInit() {
        let promise = Promise<Void>(withQueue: bgQueue) {
            throw NSError(domain: "domain", code: PromiseTestErrorCode, userInfo: nil)
        }
        let expectError = self.expectation(description: "expect the promise to have failed")
        promise.onRenege { err in
            XCTAssertEqual((err as NSError).code, PromiseTestErrorCode)
            expectError.fulfill()
        }
        self.waitForExpectations(timeout: 1)
    }
    
    // MARK: - XCTestCase+Promise
    func testExpectedPromise() {
        let promise = self.expectedPromise(withName: "test promise should be kept")
        promise.keep(withValue: ())
        self.waitForExpectations(timeout: 1)
    }
    
    func testExpectResult() {
        let promise = Promise<Int>(withQueue: bgQueue)
        self.expect(promise: promise, hasResult: 5, withName: "result should be 5")
        promise.keep(withValue: 5)
        self.waitForExpectations(timeout: 1)
    }
}
