//
//  DeferredTests.swift
//  DeferredTests
//
//  Created by Justin Driscoll on 10/31/15.
//  Copyright © 2015 Retrobit, LLC. MIT License.
//

import XCTest
@testable import Deferred

func dispatch_main_after(interval: NSTimeInterval, block: () -> ()) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(NSTimeInterval(NSEC_PER_SEC)*interval)),
        dispatch_get_main_queue(), block)
}

private let testTimeout: NSTimeInterval = 1

class DeferredTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testPeak() {
        let d = Deferred<Int>()
        XCTAssertEqual(d.peek(), nil)
        d.fill(1)
        XCTAssertEqual(d.peek(), .Some(1))
    }

    func testFilled() {
        let d = Deferred<Int>(value: 1)
        XCTAssertEqual(d.value, 1)
    }

    func testFillWhenUnfilled() {
        let d = Deferred<Int>()
        d.fill(1)
        XCTAssertEqual(d.value, 1)
    }

    func testFillWhenFilled() {
        let d = Deferred<Int>(value: 1)
        d.fill(2, assertUnfilled: false)
        XCTAssertEqual(d.value, 1)
    }

    func testValueBlocksWhileUnfilled() {
        let d = Deferred<Int>()

        let expect = expectationWithDescription("value blocks while unfilled")
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            _ = d.value
            XCTFail("value did not block")
        }
        dispatch_main_after(0.1) {
            expect.fulfill()
        }
        waitForExpectationsWithTimeout(testTimeout, handler: nil)
    }

    func testValueUnblocksWhenUnfilledIsFilled() {
        let d = Deferred<Int>()
        let expect = expectationWithDescription("value blocks until filled")
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            XCTAssertEqual(d.value, 3)
            expect.fulfill()
        }
        dispatch_main_after(0.1) {
            d.fill(3)
        }
        waitForExpectationsWithTimeout(testTimeout, handler: nil)
    }

    func testThatItCallsItsObserversWhenFilled() {
        let d = Deferred<Int>()
        let expect = self.expectationWithDescription("observers called when filled")
        d.then { i in
            XCTAssertEqual(i, 1)
            expect.fulfill()
        }
        d.fill(1)
        waitForExpectationsWithTimeout(testTimeout, handler: nil)
    }

    func testThatItDoesntCallObserversWhenUnfilled() {
        let d = Deferred<Int>()
        d.then { _ in
            XCTFail("Observer should not be called until filled")
        }
        let expect = expectationWithDescription("observers not called while deferred is unfilled")
        dispatch_main_after(0.1) {
            expect.fulfill()
        }
        waitForExpectationsWithTimeout(testTimeout, handler: nil)
    }

    func testConcurrentBlocks() {
        let d = Deferred<Int>()
        let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)

        for i in 0..<32 {
            let expectBlockCalled = expectationWithDescription("block \(i)")
            dispatch_async(queue) {
                d.then { _ in expectBlockCalled.fulfill() }
            }
        }

        dispatch_async(queue) { d.fill(1) }

        waitForExpectationsWithTimeout(testTimeout, handler: nil)
    }

    func testAll() {
        var d = [Deferred<Int>]()

        for _ in 0..<10 {
            d.append(Deferred<Int>())
        }

        let a = all(d)
        let expect = expectationWithDescription("all results filled in")

        a.then { values in
            XCTAssertEqual(values.count, d.count)
            expect.fulfill()
        }

        // Leave first unfilled
        for i in 1..<d.count {
            d[i].fill(i)
        }

        dispatch_main_after(0.1) {
            XCTAssertTrue(d[0].peek() == nil)
            d[0].fill(0)
        }

        waitForExpectationsWithTimeout(testTimeout, handler: nil)
    }

    func testAny() {
        var d = [Deferred<Int>]()

        for _ in 0..<10 {
            d.append(Deferred<Int>())
        }

        let a = any(d)
        let expect = expectationWithDescription("one result filled in")

        a.then { d in
            XCTAssertEqual(d.value, 0)
            expect.fulfill()
        }

        dispatch_main_after(0.1) {
            XCTAssertTrue(d[0].peek() == nil)
            for i in 0..<d.count {
                d[i].fill(i)
            }
        }
        
        waitForExpectationsWithTimeout(testTimeout, handler: nil)
    }
}
