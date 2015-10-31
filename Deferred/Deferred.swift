//
//  Deferred.swift
//  Deferred
//
//  Created by Justin Driscoll on 10/31/15.
//  Copyright © 2015 Retrobit, LLC. MIT License.
//

import Foundation

public final class Deferred<T> {

    public init(value: T?) {
        self.protected.value = value
    }

    public convenience init() {
        self.init(value: nil)
    }

    /// Returns true if the deferred has been filled
    public var isFilled: Bool {
        var isFilled = false
        dispatch_sync(serialQueue) {
            isFilled = self.protected.value != nil
        }
        return isFilled
    }

    /// Sets the value for the deferred and executes all current observers.
    public func fill(value: T, assertUnfilled: Bool = true) {

        var blocks: [T -> Void] = []

        dispatch_sync(serialQueue) {
            if assertUnfilled {
                precondition(self.protected.value == nil, "You cannot fill a deferred more than once")
                self.protected.value = value
            }
            else if self.protected.value == nil {
                self.protected.value = value
            }

            blocks = self.protected.blocks
            self.protected.blocks.removeAll(keepCapacity: false)
        }

        for block in blocks {
            dispatch_async(observerQueue) {
                block(value)
            }
        }
    }

    /// Returns an optional containing the current value.
    public func peek() -> T? {
        var maybeValue: T?
        dispatch_sync(serialQueue) {
            maybeValue = self.protected.value
        }
        return maybeValue
    }

    /// The value for this deferred. This will block the current thread until the value is filled.
    public var value: T {
        if let value = peek() {
            return value
        }

        //  Block until filled
        let group = dispatch_group_create()
        var value: T!
        dispatch_group_enter(group)
        then { value = $0; dispatch_group_leave(group) }
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
        return value
    }

    // MARK - Observers

    /// Adds an block that will be executed when this deferred is filled or executed immediately if it already have a value.
    public func then(block: T -> Void) {

        var maybeValue: T?

        dispatch_sync(serialQueue) {
            if self.protected.value == nil {
                self.protected.blocks.append(block)
            }
            maybeValue = self.protected.value
        }

        if let value = maybeValue {
            dispatch_async(observerQueue) {
                block(value)
            }
        }
    }

    // MARK - Private

    // All observers are executed on a global queue
    private let observerQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)

    // All access to the observers and value must occur on this serial queue
    private let serialQueue = dispatch_queue_create("com.retrobitops.deferredqueue", DISPATCH_QUEUE_SERIAL)

    // Our protected "state", both the value and current observers
    private var protected: (value: T?, blocks: [T -> Void]) = (nil, [])
}

// MARK - Bind and map

extension Deferred {

    public func bind<U>(f: T -> Deferred<U>) -> Deferred<U> {
        let d = Deferred<U>()
        self.then {
            f($0).then {
                d.fill($0)
            }
        }
        return d
    }

    public func map<U>(f: T -> U) -> Deferred<U> {
        return bind { t in Deferred<U>(value: f(t)) }
    }
}

// MARK - Free functions

/// Returns a new Deferred that calls observers when all provided deferreds are filled.
public func all<T>(deferreds: Deferred<T>...) -> Deferred<[T]> {
    return all(deferreds)
}

/// Returns a new Deferred that calls observers when all provided deferreds are filled.
public func all<T>(deferreds: [Deferred<T>]) -> Deferred<[T]> {
    if deferreds.count == 0 {
        return Deferred<[T]>(value: [])
    }

    let combined = Deferred<[T]>()
    var values = [T]()
    values.reserveCapacity(deferreds.count)

    var block: (T ->Void)!
    block = { t in
        values.append(t)
        if values.count == deferreds.count {
            combined.fill(values)
        }
        else {
            deferreds[values.count].then(block)
        }
    }
    deferreds[0].then(block)

    return combined
}

/// Returns a new Deferred that calls observers when any of the provided deferreds are filled.
public func any<T>(deferreds: Deferred<T>...) -> Deferred<Deferred<T>> {
    return any(deferreds)
}

/// Returns a new Deferred that calls observers when any of the provided deferreds are filled.
public func any<T>(deferreds: [Deferred<T>]) -> Deferred<Deferred<T>> {
    let combined = Deferred<Deferred<T>>()
    for d in deferreds {
        d.then { _ in
            combined.fill(d, assertUnfilled: false)
        }
    }
    return combined
}
