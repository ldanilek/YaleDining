//
//  Promise+Sync.swift
//  Yale
//
//  Created by Lee on 3/18/17.
//  Copyright © 2017 Yale STC Developers. All rights reserved.
//

import Foundation

/**
 * Synchronizer for the Promise class
 * Do not use unless you have a very good reason to do so.
 * These methods block the current thread until a result is received.
 * As it suspends the current thread, all dispatch queues used to create
 * the promise and used for all callbacks must be distinct from the current thread.
 */
public extension Promise {
    private func time(timeout: TimeInterval) -> DispatchTime {
        let nanoseconds = Int(Double(timeout) * Double(1000000000))
        return .now() + DispatchTimeInterval.nanoseconds(nanoseconds)
    }
    
    public func syncValue(timeout: TimeInterval = 1) -> T? {
        let (success, _) = syncResult(timeout: timeout, skipErrors: true)
        return success
    }
    
    public func syncExcuse(timeout: TimeInterval = 1) -> Error? {
        let (_, error) = syncResult(timeout: timeout)
        return error
    }
    
    public func syncResult(timeout: TimeInterval = 1, skipErrors: Bool = false) -> (T?, Error?) {
        var successResult: T?
        var errorResult: Error?
        let semaphore = DispatchSemaphore(value: 0)
        let callbackQueue = DispatchQueue(label: "sync.promise.sdmp.yale")
        self.onRenege(withQueue: callbackQueue, { error in
            errorResult = error
            if !skipErrors {
                semaphore.signal()
            }
        }).onKeep(withQueue: callbackQueue, { success in
            successResult = success
            semaphore.signal()
        })
        _ = semaphore.wait(timeout: time(timeout: timeout))
        return (successResult, errorResult)
    }
}
