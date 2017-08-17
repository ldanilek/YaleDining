//
//  NetworkManagerMockTests.swift
//  Yale
//
//  Created by Lee on 3/21/17.
//  Copyright © 2017 Yale STC Developers. All rights reserved.
//

import XCTest
@testable import Yale_Dining

class NetworkManagerMockTests: XCTestCase {
    
    let url = URL(string: "http://www.google.com/")!
    let mock = NetworkManagerMock()
    let queue = OperationQueue()
    
    override func setUp() {
        queue.maxConcurrentOperationCount = 1
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    class SimpleDelegate: SimpleURLSessionDataDelegate {
        let expectedResponse: URLResponse
        let disposition: URLSession.ResponseDisposition
        var expectedDataChunks: [Data]
        let expectedError: Error?
        var expectations: [XCTestExpectation]
        init(response: URLResponse, dispo: URLSession.ResponseDisposition, chunks: [Data], err: Error?, expectations: [XCTestExpectation]) {
            self.expectedResponse = response
            self.disposition = dispo
            self.expectedDataChunks = chunks
            self.expectedError = err
            self.expectations = expectations
        }
        func urlSession(didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
            XCTAssert(response.isEqual(expectedResponse))
            completionHandler(disposition)
            self.expectations.removeFirst().fulfill()
        }
        func urlSession(didReceive data: Data) {
            XCTAssert((data as NSData).isEqual(to: expectedDataChunks.removeFirst()))
            self.expectations.removeFirst().fulfill()
        }
        func urlSession(didCompleteWithError error: Error?) {
            XCTAssertEqual(error as NSError?, self.expectedError as NSError?)
            self.expectations.removeFirst().fulfill()
        }
    }
    
    func greatExpectations(_ dataChunkCount: Int) -> [XCTestExpectation] {
        var expectations = [self.expectation(description: "expect response")]
        for chunk in 0..<dataChunkCount {
            expectations.append(self.expectation(description: "expect data chunk \(chunk) to be read"))
        }
        expectations.append(self.expectation(description: "expect completion"))
        return expectations
    }
    
    func testResponseWithCallback() {
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mock.expect(forURL: url, response: response, disposition: .allow, expectDispo: expectedPromise(), dataChunks: [], error: nil)
        let delegate = SimpleDelegate(response: response, dispo: .allow, chunks: [], err: nil, expectations: self.greatExpectations(0))
        mock.beginDataTaskForURL(url, withDelegate: delegate, delegateQueue: queue)
        self.waitForExpectations(timeout: 1)
    }
    
    func testCancel() {
        let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
        // the cancel dispo should make it ignore data chunks and error, just not call any mehods after response.
        mock.expect(forURL: url, response: response, disposition: .cancel, expectDispo: expectedPromise(), dataChunks: [Data()], error: nil)
        let delegate = SimpleDelegate(response: response, dispo: .cancel, chunks: [], err: nil, expectations: [self.expectation(description: "expect response")])
        mock.beginDataTaskForURL(url, withDelegate: delegate, delegateQueue: queue)
        self.waitForExpectations(timeout: 1)
    }
    
    func testDataChunks() {
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let chunks = [Data(), Data(), Data()]
        mock.expect(forURL: url, response: response, disposition: .allow, expectDispo: expectedPromise(), dataChunks: chunks, error: nil)
        let delegate = SimpleDelegate(response: response, dispo: .allow, chunks: chunks, err: nil, expectations: self.greatExpectations(3))
        mock.beginDataTaskForURL(url, withDelegate: delegate, delegateQueue: queue)
        self.waitForExpectations(timeout: 1)
    }
    
    func testError() {
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let chunks = [Data()]
        let error = NSError(domain: "broken pipe", code: 402, userInfo: nil)
        mock.expect(forURL: url, response: response, disposition: .allow, expectDispo: expectedPromise(), dataChunks: chunks, error: error)
        let delegate = SimpleDelegate(response: response, dispo: .allow, chunks: chunks, err: error, expectations: self.greatExpectations(1))
        mock.beginDataTaskForURL(url, withDelegate: delegate, delegateQueue: queue)
        self.waitForExpectations(timeout: 1)
    }
}
