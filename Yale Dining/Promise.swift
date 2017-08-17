//
//  Promise.swift
//  Yale
//
//  Created by Lee on 3/18/17.
//  Copyright © 2017 Yale STC Developers. All rights reserved.
//

import UIKit

/**
 * Promise class, used as a wrapper for a value which might not exist yet.
 * For example, an API call may return a promise as its result.
 * When creating a promise, use init() to create it and one (or more) of these methods
 * to send updates to subscribers:
 * keep(withValue:), renege(withExcuse:), postpone(withPromise:), reportProgress(partial:, of:)
 * When receiving data from a promise, subscribe to updates with callbacks using
 * onKeep(_:), onRenege(_:), onProgress(_:)
 * The return values of the callbacks allow for chained transformations and centralized error handling.
 * See PromiseTests for demonstration of functionality.
 */

public enum PromiseResult<T> {
    case Value(T) // keep child promises
    case Excuse(Error) // renege on child promises
    case Progress(Int, Int) // notify child promises of progress
    case Promise(Promise<T>) // postpone current promise
}
public typealias PromiseKeepHandler<T,U> = (T) throws->PromiseResult<U>
public typealias PromiseRenegeHandler<U> = (Error) throws->PromiseResult<U>
public typealias PromiseProgressHandler<U> = (Int, Int) throws->PromiseResult<U>

let PromiseErrorDomain = "promise.sdmp.yale"

/**
 * A child promise waits on the parent with custom subscription transformations.
 * For example, if the parent is a promise of an API result, one child promise can be in charge of
 * displaying the results. On successful download, the keepHandler can deserialize the
 * JSON object. On failed download, the renegeHandler can display an error.
 * Promises can be chained by creating children of children. In the above example, a grandchild would
 * be a promise which yields the deserialized data on success.
 * If there is no handler, promise results fall-through to children directly.
 */

/**
 * Note about chaining:
 * Swift generics along with closures allow for chained promises to channel transformations.
 * Value results cannot be channelled through renege and progress blocks, unless types allow for implicit conversion.
 */

/**
 * Degenerate use-cases:
 * Promise<Void> can be used for notifications with no resulting value.
 * Promise<Bool> and Promise<Error> and Promise<Optional<_>> are possible,
 * but generally they don't provide any more power than Promise<Void>,
 * which can use errors to report failure as needed.
 */

/**
 * Extended use cases:
 * While typically a promise should be kept or reneged or postponed, i.e. completed, exactly once,
 * nothing in the implementation prevents successful keeping multiple times
 * or multiple failures reported before a successful result.
 * A promise should conform to the typical use case (only being completed once), unless
 * a different use case is explicitly noted in the documentation.
 */

private typealias PromiseUpdateHandler<T> = (PromiseResult<T>)->Void // value, error, or progress

public class Promise<T>: NSObject {
    /**
     * To avoid concurrency bugs we use serial DispatchQueues, instead of
     * OperationQueues, which are by default concurrent. DispatchQueues also guarantee
     * FIFO ordering, unlike OperationQueues which reorder based on priority and dependencies.
     */
    private let queue: DispatchQueue
    /**
     * The most recent update is stored here.
     * Only set/get on self.queue
     */
    private var result: PromiseResult<T>?
    
    /**
     * Tells whether self is the root of a promise
     * If it isn't we can't let the user update it, updates have to come from the parent.
     */
    private var isRootPromise: Bool = true
    
    /**
     * Designated initializer. Create a promise.
     * Queue is used for serializing operations on the promise (prevent race conditions)
     * and it's used as the default for completion handlers.
     */
    init(withQueue queue: DispatchQueue = DispatchQueue.main) {
        // MUST BE A SERIAL DISPATCH QUEUE (it appears to be impossible to assert)
        self.queue = queue
    }
    /**
     * Used to initialize children inside onUpdate.
     */
    private init(asChildWithQueue queue: DispatchQueue) {
        self.queue = queue
        self.isRootPromise = false
    }
    
    convenience init(withQueue queue: DispatchQueue = DispatchQueue.main, result generator: @escaping (Void) throws->PromiseResult<T>) {
        self.init(withQueue: queue)
        queue.async {
            do {
                self.update(with: try generator())
            } catch {
                self.update(with: .Excuse(error))
            }
        }
    }
    /**
     * General method can be called from any queue to save update to
     * a promise, and trigger all update handlers.
     */
    private func update(with result: PromiseResult<T>) {
        queue.async {
            // result may be a postponement,
            // for which notifications should not be sent immediately
            switch result {
            case let .Promise(promise):
                promise.forwardToPromiseOnUpdate(self)
            default:
                self.result = result
                for updateHandler in self.updateHandlers {
                    updateHandler(result)
                }
            }
        }
    }
    /**
     * Call these functions (from any queue) to signify that
     * a promise has been kept, reneged upon, or that
     * progress has been made
     */
    public func keep(withValue value: T) {
        precondition(self.isRootPromise, "You can only call keep on a root promise.")
        self.update(with: .Value(value))
    }
    // do not create a cycle of postponed promises, because that would leak memory
    // and cause an infinite loop if any of the promises get an update.
    public func postpone(withPromise promise: Promise<T>) {
        precondition(self.isRootPromise, "You can only call postpone on a root promise.")
        self.update(with: .Promise(promise))
    }
    public func renege(withExcuse excuse: Error) {
        precondition(self.isRootPromise, "You can only call renege on a root promise.")
        self.update(with: .Excuse(excuse))
    }
    public func reportProgress(partial: Int, of: Int) {
        precondition(self.isRootPromise, "You can only call report progress on a root promise.")
        self.update(with: .Progress(partial, of))
    }
    
    /**
     * Array of closures to call on update.
     * Closures may be called from any queue. They return immediately.
     * Closures must not contain strong references to this promise,
     * because that would create a reference loop.
     * Only read/write this array on self.queue
     */
    private var updateHandlers: [PromiseUpdateHandler<T>] = []
    
    /**
     * Subscribes the receiver |self| to updates from |promise|.
     * When |promise| is updated, all of |self.updateHandlers| will be
     * called. Forwards of promises can be chained, but there should
     * be no cycle in the chain.
     */
    private func forwardToPromiseOnUpdate(_ promise: Promise<T>) {
        let promiseHandler: PromiseUpdateHandler<T> = { result in
            promise.update(with: result)
        }
        self.queue.async {
            if let result = self.result {
                promiseHandler(result)
            }
            self.updateHandlers.append(promiseHandler)
        }
    }
    
    /**
     * Converts value from type T->PromiseResult<U>, if possible.
     * To do this it uses the keepHandler if avaliable.
     */
    private class func convertValue<U>(_ value: T,
                                    onKeep keepHandler: PromiseKeepHandler<T,U>?) throws -> PromiseResult<U> {
        if let transformedResult = try keepHandler?(value) {
            return transformedResult
        } else if let transformedValue = value as? U {
            // try to perform implicit conversion, which allows fallthrough of String->String, String->Any, etc.
            return .Value(transformedValue)
        } else {
            // this is why value results can't be channelled through renege and progress blocks.
            // it's impossible to convert T->U without a conversion closure.
            // in order to avoid silent failings, report an error
            return .Excuse(NSError(domain: PromiseErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: "Promise value cannot be transformed without explicit |onFulfill| closure."]))
        }
    }
    
    /**
     * Calls relevant handler, and updates resultPromise based on its return value.
     */
    private class func callHandler<U>(withResult result: PromiseResult<T>,
                                   onKeep keepHandler: PromiseKeepHandler<T,U>?,
                                   onRenege renegeHandler: PromiseRenegeHandler<U>?,
                                   onProgress progressHandler: PromiseProgressHandler<U>?,
                                   andSendResultTo resultPromise: Promise<U>) {
        var transformed: PromiseResult<U>
        do {
            switch result {
            case let .Excuse(err):
                transformed = (try renegeHandler?(err)) ?? .Excuse(err)
            case let .Value(val):
                transformed = try convertValue(val, onKeep: keepHandler)
            case let .Progress(partial, of):
                transformed = (try progressHandler?(partial, of)) ?? .Progress(partial, of)
            case .Promise(_):
                // assert instead of updating with error because this should be unreachable
                assert(false, "Promise handler should not be called with postponing promise.")
                return
            }
        } catch {
            transformed = .Excuse(error)
        }
        resultPromise.update(with: transformed)
    }
    
    /**
     * Create child promises with these methods.
     */
    @discardableResult
    private func onUpdate<U>(withQueue queue: DispatchQueue,
                          onKeep keepHandler: PromiseKeepHandler<T,U>? = nil,
                          onRenege renegeHandler: PromiseRenegeHandler<U>? = nil,
                          onProgress progressHandler: PromiseProgressHandler<U>? = nil) -> Promise<U> {
        let chainedPromise = Promise<U>(asChildWithQueue: queue)
        let promiseHandler: PromiseUpdateHandler<T> = { result in
            queue.async {
                Promise.callHandler(withResult: result,
                                    onKeep: keepHandler,
                                    onRenege: renegeHandler,
                                    onProgress: progressHandler,
                                    andSendResultTo: chainedPromise)
            }
        }
        self.queue.async {
            // if this promise is already done, notify the child immediately
            if let result = self.result {
                promiseHandler(result)
            }
            // child subscribes to updates, even if result existed, in case the result was just Progress.
            self.updateHandlers.append(promiseHandler)
        }
        return chainedPromise
    }
    
    /**
     * Methods for creating child promises.
     * Handlers are executed asynchronously on the provided queues.
     * Handlers MUST NOT contain strong references to promise |self|, because
     * that would create a strong reference loop, leading to a memory leak.
     * Handlers may have unowned or weak references to |self|.
     */
    @discardableResult
    public func onKeep<U>(withQueue queue: DispatchQueue? = nil,
                          _ handler: @escaping PromiseKeepHandler<T,U>) -> Promise<U> {
        return onUpdate(withQueue: queue ?? self.queue, onKeep: handler)
    }
    @discardableResult
    public func onRenege<U>(withQueue queue: DispatchQueue? = nil,
                         _ handler: @escaping PromiseRenegeHandler<U>) -> Promise<U> {
        return onUpdate(withQueue: queue ?? self.queue, onRenege: handler)
    }
    @discardableResult
    public func onProgress<U>(withQueue queue: DispatchQueue? = nil,
                           _ handler: @escaping PromiseProgressHandler<U>) -> Promise<U> {
        return onUpdate(withQueue: queue ?? self.queue, onProgress: handler)
    }
    /**
     * Degenerate cases, allowing full fallthrough.
     * Use these if you want to write simpler callbacks and don't
     * need to pass on special information to child promises.
     */
    @discardableResult
    public func onKeep(withQueue queue: DispatchQueue? = nil,
                       _ handler: @escaping (T) throws->Void) -> Promise<T> {
        return onKeep(withQueue: queue ?? self.queue) { (value)->PromiseResult<T> in
            try handler(value)
            return .Value(value)
        }
    }
    @discardableResult
    public func onRenege(withQueue queue: DispatchQueue? = nil,
                         _ handler: @escaping (Error) throws->Void) -> Promise<T> {
        return onRenege(withQueue: queue ?? self.queue) { (err)->PromiseResult<T> in
            try handler(err)
            return .Excuse(err)
        }
    }
    @discardableResult
    public func onProgress(withQueue queue: DispatchQueue? = nil,
                           _ handler: @escaping (Int, Int) throws->Void) -> Promise<T> {
        return onProgress(withQueue: queue ?? self.queue) { (partial, of)->PromiseResult<T> in
            try handler(partial, of)
            return .Progress(partial, of)
        }
    }
}

