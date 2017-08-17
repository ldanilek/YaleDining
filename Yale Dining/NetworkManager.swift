//
//  NetworkManager.swift
//  Yale
//
//  Created by Lee on 4/7/17.
//  Copyright © 2017 Yale STC Developers. All rights reserved.
//

import UIKit

/**
 * Main protocol. Connections to the network should go through this protocol.
 */
protocol NetworkManager {
    func beginDataTaskForURL(_ url: URL, withDelegate delegate: SimpleURLSessionDataDelegate, delegateQueue: OperationQueue)
}

class StandardNetworkManager: NSObject, NetworkManager {
    func beginDataTaskForURL(_ url: URL, withDelegate delegate: SimpleURLSessionDataDelegate, delegateQueue: OperationQueue) {
        let fullDelegate = URLSessionDataDelegateSimplifier(withLayman: delegate)
        let session = URLSession(configuration: URLSessionConfiguration.default, delegate: fullDelegate, delegateQueue: delegateQueue)
        // Considered using a cache policy which does the caching for us,
        // but it issues HEAD requests if stale, which would in general make fetches
        // slower for small data. We also don't know how it's storing the cache.
        let request = URLRequest(url: url, cachePolicy: URLRequest.CachePolicy.reloadIgnoringLocalCacheData, timeoutInterval: 0)
        let dataTask = session.dataTask(with: request)
        dataTask.resume()
    }
}

/**
 * The network will be really hard to mock unless we choose not to mock most features.
 * e.g. Passing around URLSessions and URLSessionDataTasks is fine for Apple's protocols, but
 * to mock it we want to simplify: only include parts we will use.
 */
protocol SimpleURLSessionDataDelegate {
    func urlSession(didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void)
    func urlSession(didReceive data: Data)
    func urlSession(didCompleteWithError error: Error?)
}

private class URLSessionDataDelegateSimplifier: NSObject, URLSessionDataDelegate {
    let layman: SimpleURLSessionDataDelegate
    init(withLayman layman: SimpleURLSessionDataDelegate) {
        self.layman = layman
    }
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        self.layman.urlSession(didReceive: response, completionHandler: completionHandler)
    }
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        self.layman.urlSession(didReceive: data)
    }
    // completed, wants to cache
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
        completionHandler(nil) // disable auto-caching
    }
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        self.layman.urlSession(didCompleteWithError: error)
    }
}
