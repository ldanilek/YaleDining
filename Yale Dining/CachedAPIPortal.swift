//
//  CachedAPIPortal.swift
//  Yale
//
//  Created by Lee on 2/18/17.
//  Copyright © 2017 Yale STC Developers. All rights reserved.
//

import UIKit

/**
 * All connections to the internet should go through here.
 * Cache is invalidated after cacheTTL seconds.
 * Method to use is fetch(url: URL, cacheTTL: TimeInterval = 0, forceFetch: Bool = false)
 * onProgress is called with arguments (receivedBytes, expectedBytes).
 * Note expectedBytes could be smaller than receivedBytes if HTML header has incorrect content length or none.
 *
 * Algorithm description:
 * Skip reading from cache if forceFetch or stale
 * On successful read from cache, data is returned.
 * Otherwise, data is fetched from the network.
 * On successful fetch, if cacheTTL > 0, cache data and save stale time.
 * If cacheTTL <= 0, remove data from cache.
 *
 * Note this means the cache and stale time are only updated on successful fetch,
 * and fetch is only attempted if reading from cache fails.
 */
public protocol InternetInterface {
    func fetchFromAPI(url: URL, cacheTTL: TimeInterval, forceFetch: Bool) -> Promise<Data>
}
public extension InternetInterface {
    public func fetch(url: URL, cacheTTL: TimeInterval = 0, forceFetch: Bool = false) -> Promise<Data> {
        return fetchFromAPI(url: url, cacheTTL: cacheTTL, forceFetch: forceFetch)
    }
}

class CachedAPIPortal: NSObject, InternetInterface {
    // dependencies, may be overridden e.g. with mocks
    var disk: DiskManager = StandardDiskManager()
    var documentsDirectory: String? = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true).first
    var keyValueStore = UserDefaults.standard
    var time: TimeManager = StandardTimeManager()
    var network: NetworkManager = StandardNetworkManager()
    
    public static let `default` = CachedAPIPortal()
    
    public func fetchFromAPI(url: URL,
                        cacheTTL: TimeInterval,
                      forceFetch: Bool) -> Promise<Data> {
        let backgroundQueue = DispatchQueue(label: "background.api_portal.sdmp.yale")
        // try to fetch from cache. if that fails, fetch from url and cache.
        return readFromCache(forURL: url, forceFetch: forceFetch)
            .onRenege(withQueue: backgroundQueue) { err -> PromiseResult<Data> in
            print("Failed to access data in cache for URL \(url)")
            return .Promise(self.fetchFromURL(url, andCacheWithTTL: cacheTTL))
        }
    }
    
    private func cacheIsStale(forURL url: URL) -> Bool {
        if let date = self.keyValueStore.object(forKey: timeoutKey(forURL: url)) as? Date {
            return date.timeIntervalSince(self.time.now()) < 0
        }
        return true
    }
    
    // returns promise which yields the given data on success, or reneges with error
    private func cacheData(_ data: Data, withTTL cacheTTL: TimeInterval, forURL url: URL, onQueue queue: DispatchQueue) -> Promise<Data> {
        return pathForCachingAPI(url: url).onKeep(withQueue: queue, { path -> PromiseResult<Void> in
            let timeoutKey = self.timeoutKey(forURL: url)
            if cacheTTL > 0 {
                let timeoutDate = self.time.now().addingTimeInterval(cacheTTL)
                return .Promise(self.disk.writeData(data, to: path)
                    .onKeep(withQueue: queue) {
                    self.keyValueStore.set(timeoutDate, forKey: timeoutKey)
                })
            } else {
                // invalidate the cache
                self.keyValueStore.removeObject(forKey: timeoutKey)
                return .Promise(self.disk.removeItemAsync(at: path)
                    .onRenege(withQueue: queue, { _ -> PromiseResult<Void> in
                    // if file doesn't exist, no problem
                    return .Value()
                }))
            }
        }).onKeep { ()->PromiseResult<Data> in
            return .Value(data)
        }
    }
    
    private func timeoutKey(forURL url: URL) -> String {
        return "Timeout date for URL: \(url)"
    }
    
    private func removeTimeoutCookie(forURL url: URL) {
        self.keyValueStore.removeObject(forKey: self.timeoutKey(forURL: url))
        self.keyValueStore.synchronize()
    }
    
    private func fetchFromURL(_ url: URL, andCacheWithTTL cacheTTL: TimeInterval) -> Promise<Data> {
        let fetchPromise = fetchFromURL(url)
        let cacheQueue = DispatchQueue(label: "write.cache.api_portal.sdmp.yale")
        return fetchPromise.onKeep(withQueue: cacheQueue, { data->PromiseResult<Data> in
            let cache = self.cacheData(data, withTTL: cacheTTL, forURL: url, onQueue: cacheQueue).onRenege { error -> PromiseResult<Data> in
                print("Caching resulted in error: \(error.localizedDescription)")
                self.removeTimeoutCookie(forURL: url)
                return .Value(data)
            }
            return .Promise(cache)
        }).onRenege { error in
            print("Fetching resulted in error: \(error.localizedDescription)")
            self.removeTimeoutCookie(forURL: url)
        }
    }
    
    private func fetchFromURL(_ url: URL) -> Promise<Data> {
        let promise = Promise<Data>(withQueue: DispatchQueue(label: "fetch.api_portal.sdmp.yale"))
        let delegate = SessionDelegate(withPromise: promise)
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        self.network.beginDataTaskForURL(url, withDelegate: delegate, delegateQueue: queue)
        return promise
    }
    
    // if cache is allowed, read from it and return the data
    // cacheConfig.fileManager is only accessed from background thread
    private func readFromCache(forURL url: URL, forceFetch: Bool) -> Promise<Data> {
        let readCacheQueue = DispatchQueue(label: "read.cache.api_portal.sdmp.yale")
        return Promise(withQueue: readCacheQueue) {
            if forceFetch || self.cacheIsStale(forURL: url) {
                throw NSError(domain: "read.cache.api_portal.sdmp.yale", code: 0, userInfo: [NSLocalizedDescriptionKey: "Cache is stale or fetch is forced."])
            }
            return .Promise(self.pathForCachingAPI(url: url)
                .onKeep(withQueue: readCacheQueue, { (path) -> PromiseResult<Data> in
                return .Promise(self.disk.readData(contentsOf: path))
            }))
        }
    }
    
    private let pathQueue = DispatchQueue(label: "path.cache.api_portal.sdmp.yale")
    
    private func directoryForCaching() -> Promise<String> {
        if let path = self.documentsDirectory {
            let basePath = NSString(string: path).appendingPathComponent("cached_api_responses")
            return self.disk.fileExistsAsync(atPath: basePath)
                .onKeep(withQueue: pathQueue) { (exists, isDir) -> PromiseResult<String> in
                if exists {
                    if isDir {
                        return .Value(basePath)
                    } else {
                        throw NSError(domain: "path.cache.api_portal.sdmp.yale", code: 0, userInfo: [NSLocalizedDescriptionKey: "Cache directory exists as a file"])
                    }
                } else {
                    return .Promise(self.disk.createDirectoryAsync(atPath: basePath)
                        .onKeep(withQueue: self.pathQueue, { _ -> PromiseResult<String> in
                        return .Value(basePath)
                    }))
                }
            }
        }
        return Promise(withQueue: pathQueue) {
            throw NSError(domain: "path.cache.api_portal.sdmp.yale", code: 0, userInfo: [NSLocalizedDescriptionKey: "Cannot find documents directory"])
        }
    }
    
    private func pathForCachingAPI(url: URL) -> Promise<URL> {
        if let escaped = NSString(string: url.absoluteString).addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics) {
            return directoryForCaching().onKeep { path -> PromiseResult<URL> in
                let fullPath = NSString(string: path).appendingPathComponent(escaped)
                return .Value(URL(fileURLWithPath: fullPath))
            }
        }
        return Promise(withQueue: pathQueue) {
            throw NSError(domain: "path.cache.api_portal.sdmp.yale", code: 0, userInfo: [NSLocalizedDescriptionKey: "Cannot get path for URL \(url)"])
        }
    }
}

class SessionDelegate: NSObject, SimpleURLSessionDataDelegate {
    var totalDataExpected = 0
    var totalDataReceived = 0
    let accumulatedData = NSMutableData()
    
    let promise: Promise<Data> // for sending results
    init(withPromise promise: Promise<Data>) {
        self.promise = promise
        super.init()
    }
    
    // initial response, containing header
    public func urlSession(didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        // server errors show up in the URLResponse (not in the error delegate method)
        if let response = response as? HTTPURLResponse {
            // the only acceptable status code is 200
            if response.statusCode != 200 {
                promise.renege(withExcuse: NSError(domain: HTTPURLResponse.localizedString(forStatusCode: response.statusCode), code: response.statusCode, userInfo: response.allHeaderFields))
                completionHandler(URLSession.ResponseDisposition.cancel)
                return
            }
        }
        totalDataExpected = Int(response.expectedContentLength)
        promise.reportProgress(partial: 0, of: totalDataExpected)
        completionHandler(URLSession.ResponseDisposition.allow)
    }
    // received some data
    public func urlSession(didReceive data: Data) {
        accumulatedData.append(data)
        totalDataReceived += data.count
        promise.reportProgress(partial: totalDataReceived, of: totalDataExpected)
    }
    // completed
    func urlSession(didCompleteWithError error: Error?) {
        if let error = error {
            promise.renege(withExcuse: error)
        } else {
            promise.keep(withValue: accumulatedData.copy() as! Data)
        }
    }
}
