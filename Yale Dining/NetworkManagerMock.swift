//
//  NetworkManagerMock.swift
//  Yale
//
//  Created by Lee on 3/21/17.
//  Copyright © 2017 Yale STC Developers. All rights reserved.
//

import UIKit

class NetworkManagerMock: NSObject, NetworkManager {
    private var expected: [URL: (URLResponse, URLSession.ResponseDisposition, Promise<Void>?, [Data], Error?)] = [:]
    
    func expect(forURL url: URL, response: URLResponse, disposition: URLSession.ResponseDisposition, expectDispo: Promise<Void>?, dataChunks: [Data], error: Error?) {
        expected[url] = (response, disposition, expectDispo, dataChunks, error)
    }
    
    func beginDataTaskForURL(_ url: URL, withDelegate delegate: SimpleURLSessionDataDelegate, delegateQueue: OperationQueue) {
        assert(delegateQueue.maxConcurrentOperationCount == 1) // avoid race conditions
        if let (response, disposition, expectDispo, dataChunks, error) = expected[url] {
            delegateQueue.addOperation {
                delegate.urlSession(didReceive: response, completionHandler: { (dispo) in
                    assert(dispo == disposition)
                    expectDispo?.keep(withValue: ())
                })
            }
            if disposition == .allow {
                for dataChunk in dataChunks {
                    delegateQueue.addOperation {
                        delegate.urlSession(didReceive: dataChunk)
                    }
                }
                delegateQueue.addOperation {
                    delegate.urlSession(didCompleteWithError: error)
                }
            }
        }
    }
}
