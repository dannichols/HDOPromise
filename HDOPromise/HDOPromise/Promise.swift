//
//  Promise.swift
//  HDOPromise
//
//  Created by Daniel Nichols on 3/21/16.
//  Copyright © 2016 Hey Danno. All rights reserved.
//

import Foundation.NSError

/// Promises are used to track operations that may be deferred or performed asynchronously.
public class Promise<T> {
    
    /// Executor callback is used to run the promised operation. When the operation is finished,
    /// it should either call `onFulfilled` or `onRejected` with the operation's result or the error
    /// that occurred.
    /// - parameter onFulfilled: The function that must be called when the operation succeeds
    /// - parameter onRejected: The function that must be called when the operation fails
    public typealias ExecutorCallback = (onFulfilled: ResolveCallback, onRejected: RejectCallback) -> Void
    
    /// Executor callback is used to run the promised operation. When the operation is finished,
    /// it should either call `onFulfilled` or `onRejected` with the operation's result or the error
    /// that occurred.
    /// - parameter onFulfilled: The function that must be called when the operation succeeds
    /// - parameter onRejected: The function that must be called when the operation fails
    /// - parameter onProgress: The function that must be called when progress is made towards completing the operation
    public typealias ExecutorWithProgressCallback = (onFulfilled: ResolveCallback, onRejected: RejectCallback, onProgress: ProgressCallback) -> Void
    
    /// A finished callback is called when the promised operation is no longer running.
    public typealias AlwaysCallback = () -> Void
    
    /// A success callback is called when the promised operation has completed successfully.
    /// - parameter result: The outcome of the operation
    public typealias ResolveCallback = (T) -> Void
    
    /// An error callback is called when the promised operation has failed.
    /// - parameter error: The reason that the operation failed
    public typealias RejectCallback = (ErrorType) -> Void
    
    /// A progress callback is called when the promised operation updates its status.
    /// - parameter percent: The relative completeness of the operation
    /// - parameter message: An optional message describing the operation's progress
    public typealias ProgressCallback = (Double, String?) -> Void
    
    /// Creates a promise that finishes once either all supplied promises have succeeded or once
    /// one of the supplied promises has failed. On success, this promise's result will be a list
    /// of the results of the supplied promises in the same order as those promises were supplied.
    /// On failure, this promise's error will be the error reported by the first failed promise.
    /// - parameter promises: A list of promises whose outcomes will be tracked
    /// - returns: A new promise wrapping the input promises
    public class func all(promises: [Promise<T>]) -> Promise<[T]> {
        return Promise<[T]> { (onFulfilled, onRejected) in
            var outstanding = promises.count
            var results = [T?](count: outstanding, repeatedValue: nil)
            var hasErrorOccurred = false
            for i in 0 ..< outstanding {
                let index = i
                promises[i].then({ (result) in
                    outstanding -= 1
                    guard !hasErrorOccurred else {
                        return
                    }
                    results[index] = result
                    if outstanding == 0 {
                        onFulfilled(results.map({ $0! }))
                    }
                }).error({ (error) in
                    outstanding -= 1
                    guard !hasErrorOccurred else {
                        return
                    }
                    hasErrorOccurred = true
                    onRejected(error)
                })
            }
        }
    }
    
    /// Creates a promise that finishes as soon as the first of the supplied promises has
    /// either succeeded or failed.
    /// - parameter promises: A list of promises whose outcomes will be tracked
    /// - returns: A new promise racing the input promises
    public class func race(promises: [Promise<T>]) -> Promise<T> {
        return Promise<T> { (onFulfilled, onRejected) in
            for promise in promises {
                promise.then({ (result) in
                    onFulfilled(result)
                }).error({ (error) in
                    onRejected(error)
                })
            }
        }
    }
    
    /// Creates a new pre-failed promise.
    /// - parameter error: The failure to report
    /// - returns: A new failed promise
    public class func reject(error: ErrorType) -> Promise<T> {
        return Promise<T> { (onFulfilled, onRejected) in
            onRejected(error)
        }
    }
    
    /// Creates a new pre-succeeded promise.
    /// - parameter result: The success outcome
    /// - returns: A new succeeded promise
    public class func resolve(result: T) -> Promise<T> {
        return Promise<T> { (onFulfilled, onRejected) in
            onFulfilled(result)
        }
    }
    
    /// Creates a new promise.
    public init() {
        // Do nothing
    }
    
    /// Creates a new promise wrapping an operation that is immediately executed.
    /// - parameter executor: The operation to execute
    public init(_ executor: ExecutorCallback) {
        executor(
            onFulfilled: { (result) in
                self.resolve(result)
            },
            onRejected: { (error) in
                self.reject(error)
        })
    }
    
    /// Creates a new promise wrapping an operation that is immediately executed.
    /// - parameter executor: The operation to execute
    public init(_ executor: ExecutorWithProgressCallback) {
        executor(
            onFulfilled: { (result) in
                self.resolve(result)
            },
            onRejected: { (error) in
                self.reject(error)
            },
            onProgress: { (percent, message) in
                self.progress(percent: percent, message: message)
        })
    }
    
    /// Whether or not the promise operation has completed
    private(set) public var finished = false {
        didSet {
            self.processCallbacks()
        }
    }
    
    /// If this promise is not yet finished, reports that the promise has finished
    /// successfully with a value. If the promise has finished, this method has
    /// no effect.
    /// - parameter result: The outcome of the operation
    /// - returns: This promise (for method chaining)
    public func resolve(result: T) -> Self {
        guard !self.finished else {
            return self
        }
        self._result = result
        return self
    }
    
    /// If this promise is not yet finished, reports that the promise has finished
    /// unsuccessfully with an error. If the promise has finished, this method has
    /// no effect.
    /// - parameter error: The reason that the operation failed
    /// - returns: This promise (for method chaining)
    public func reject(error: ErrorType) -> Self {
        guard !self.finished else {
            return self
        }
        self._error = error
        return self
    }
    
    /// If this promise is not yet finished, reports progress towards completion. If
    /// the promise has finished, this method has no effect.
    /// - parameter percent: The relative completeness of the operation
    /// - parameter message: An optional message describing the operation's progress
    /// - returns: This promise (for method chaining)
    public func progress(percent percent: Double, message: String?) -> Self {
        guard !self.finished else {
            return self
        }
        for callback in self._progressCallbacks {
            callback(percent, message)
        }
        return self
    }
    
    /// Adds a callback to be executed when the promise operation has ended (regardless
    /// of whether the operation succeeded or failed). If the operation is already finished,
    /// the callback will be executed immediately.
    /// - parameter callback: The function to be called
    /// - returns: This promise (for method chaining)
    public func always(finish: AlwaysCallback) -> Self {
        if self.finished {
            finish()
        } else {
            self._alwaysCallbacks.append(finish)
        }
        return self
    }
    
    /// Adds a callback to be executed when the promise operation has ended successfully.
    /// If the operation is already succeeded, the callback will be executed immediately.
    /// - parameter callback: The function to be called
    /// - returns: This promise (for method chaining)
    public func then(success: ResolveCallback) -> Self {
        if let result = self._result {
            success(result)
        } else {
            self._resolveCallbacks.append(success)
        }
        return self
    }
    
    /// Adds a callback to be executed when the promise operation has failed.
    /// If the operation is already failed, the callback will be executed immediately.
    /// - parameter callback: The function to be called
    /// - returns: This promise (for method chaining)
    public func error(error: RejectCallback) -> Self {
        if let e = self._error {
            error(e)
        } else {
            self._rejectCallbacks.append(error)
        }
        return self
    }
    
    /// Adds a callback to be executed periodically as the promise operation proceeds.
    /// - parameter callback: The function to be called
    /// - returns: This promise (for method chaining)
    public func check(progress: ProgressCallback) -> Self {
        self._progressCallbacks.append(progress)
        return self
    }
    
    // Private
    
    private var _result: T? {
        didSet {
            self.finished = true
        }
    }
    private var _error: ErrorType? {
        didSet {
            self.finished = true
        }
    }
    private lazy var _alwaysCallbacks: [AlwaysCallback] = {
        return [AlwaysCallback]()
    }()
    private lazy var _resolveCallbacks: [ResolveCallback] = {
        return [ResolveCallback]()
    }()
    private lazy var _rejectCallbacks: [RejectCallback] = {
        return [RejectCallback]()
    }()
    private lazy var _progressCallbacks: [ProgressCallback] = {
        return [ProgressCallback]()
    }()
    
    private func processCallbacks() {
        if let e = self._error {
            for callback in self._rejectCallbacks {
                callback(e)
            }
        } else if let result = self._result {
            for callback in self._resolveCallbacks {
                callback(result)
            }
        }
        for callback in self._alwaysCallbacks {
            callback()
        }
        self._alwaysCallbacks.removeAll()
        self._resolveCallbacks.removeAll()
        self._rejectCallbacks.removeAll()
        self._progressCallbacks.removeAll()
    }
}