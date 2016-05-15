//
//  HDOPromiseTests.swift
//  HDOPromiseTests
//
//  Created by Daniel Nichols on 5/15/16.
//  Copyright © 2016 Hey Danno. All rights reserved.
//

import XCTest
@testable import HDOPromise

class PromiseTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testFinished() {
        let promise1 = Promise<Int>()
        XCTAssertEqual(promise1.finished, false, "Promise should not be finished prior to resolution")
        promise1.resolve(0)
        XCTAssertEqual(promise1.finished, true, "Promise must be finished after success")
        let promise2 = Promise<Int>()
        promise2.reject(NSError(domain: "", code: 0, userInfo: nil))
        XCTAssertEqual(promise2.finished, true, "Promise must be finished after error")
    }
    
    func testOnFinish() {
        let promise1 = Promise<Int>()
        var foo = 0
        promise1.always({
            foo += 1 // 1
        })
        XCTAssertEqual(foo, 0, "Promise does not execute finish callbacks prior to resolution")
        promise1.resolve(0)
        XCTAssertEqual(foo, 1, "Promise executes finish callbacks on successful resolution")
        promise1.always({
            foo += 1 // 2
        })
        XCTAssertEqual(foo, 2, "Promise executes finish callbacks immediately when added post-successful resolution")
        let promise2 = Promise<Int>()
        promise2.always({
            foo += 1 // 3
        })
        promise2.reject(NSError(domain: "", code: 0, userInfo: nil))
        XCTAssertEqual(foo, 3, "Promise executes finish callbacks on error resolution")
        promise2.always({
            foo += 1 // 4
        })
        XCTAssertEqual(foo, 4, "Promise executes finish callbacks immediately when added post-error resolution")
        let promise3 = Promise<Int>()
        promise3.always({ foo = 100 }).always({ foo *= 2 }).resolve(0)
        XCTAssertEqual(foo, 200, "Promise executes all finish callbacks in the sequence they were added")
        promise3.always({ foo *= 3 })
        XCTAssertEqual(foo, 600, "Promise removes finish callbacks from the queue after execution")
    }
    
    func testOnSuccess() {
        let promise1 = Promise<Int>()
        var foo = 0
        promise1.then({ (result) in
            foo = 1
        })
        XCTAssertEqual(foo, 0, "Promise does not execute success callbacks prior to resolution")
        promise1.resolve(0)
        XCTAssertEqual(foo, 1, "Promise executes success callbacks on successful resolution")
        promise1.then({ (result) in
            foo = 2
        })
        XCTAssertEqual(foo, 2, "Promise executes success callbacks immediately when added post-successful resolution")
        let promise2 = Promise<Int>()
        promise2.then({ (result) in
            foo = 3
        })
        promise2.reject(NSError(domain: "", code: 0, userInfo: nil))
        XCTAssertEqual(foo, 2, "Promise does not execute success callbacks on error resolution")
        promise2.then({ (result) in
            foo = 4
        })
        XCTAssertEqual(foo, 2, "Promise does not execute success callbacks immediately when added post-error resolution")
        promise2.resolve(0)
        XCTAssertEqual(foo, 2, "Promise cannot trigger success handlers after error resolution")
        let promise3 = Promise<Int>()
        promise3.then({ (result) in foo = 100 }).then({ (result) in foo *= 2 }).resolve(0)
        XCTAssertEqual(foo, 200, "Promise executes all success callbacks in the sequence they were added")
        promise3.then({ (result) in foo *= 3 })
        XCTAssertEqual(foo, 600, "Promise removes success callbacks from the queue after execution")
        let promise4 = Promise<Int>()
        promise4.then({ (result) in foo = result }).then({ (result) in foo *= result }).resolve(2)
        XCTAssertEqual(foo, 4, "Promise passes success resolution value to success callbacks")
        promise4.then({ (result) in foo /= result })
        XCTAssertEqual(foo, 2, "Promise retains success resolution value for future post-successful resolution callbacks")
    }
    
    func testOnError() {
        let promise1 = Promise<Int>()
        var foo = 0
        promise1.error({ (error) in
            foo = 1
        })
        XCTAssertEqual(foo, 0, "Promise does not execute error callbacks prior to resolution")
        promise1.reject(NSError(domain: "", code: 0, userInfo: nil))
        XCTAssertEqual(foo, 1, "Promise executes error callbacks on error resolution")
        promise1.error({ (error) in
            foo = 2
        })
        XCTAssertEqual(foo, 2, "Promise executes error callbacks immediately when added post-error resolution")
        let promise2 = Promise<Int>()
        promise2.error({ (error) in
            foo = 3
        })
        promise2.resolve(0)
        XCTAssertEqual(foo, 2, "Promise does not execute error callbacks on success resolution")
        promise2.error({ (error) in
            foo = 4
        })
        XCTAssertEqual(foo, 2, "Promise does not execute error callbacks immediately when added post-success resolution")
        promise2.reject(NSError(domain: "", code: 0, userInfo: nil))
        XCTAssertEqual(foo, 2, "Promise cannot trigger error handlers after success resolution")
        let promise3 = Promise<Int>()
        promise3.error({ (error) in foo = 100 }).error({ (error) in foo *= 2 }).reject(NSError(domain: "", code: 0, userInfo: nil))
        XCTAssertEqual(foo, 200, "Promise executes all error callbacks in the sequence they were added")
        promise3.error({ (error) in foo *= 3 })
        XCTAssertEqual(foo, 600, "Promise removes error callbacks from the queue after execution")
        let promise4 = Promise<Int>()
        promise4.error({ (error) in foo = (error as NSError).code }).error({ (error) in foo *= (error as NSError).code }).reject(NSError(domain: "", code: 2, userInfo: nil))
        XCTAssertEqual(foo, 4, "Promise passes error resolution value to error callbacks")
        promise4.error({ (error) in foo /= (error as NSError).code })
        XCTAssertEqual(foo, 2, "Promise retains error resolution value for future post-error resolution callbacks")
    }
    
    func testCombination() {
        var foo = 0
        Promise<Int>().then({ (result) in foo = 1 }).error({ (error) in foo = 2 }).always({ foo *= 3 }).resolve(0)
        XCTAssertEqual(foo, 3, "Promise executes success callbacks then finish callbacks on success resolution")
        foo = 0
        Promise<Int>().then({ (result) in foo = 1 }).error({ (error) in foo = 2 }).always({ foo *= 3 }).reject(NSError(domain: "", code: 0, userInfo: nil))
        XCTAssertEqual(foo, 6, "Promise executes error callbacks then finish callbacks on error resolution")
    }
    
    func testAll() {
        var foo = 0
        let a = Promise<Int>()
        let b = Promise<Int>()
        Promise.all([a, b]).then({ (result) in
            XCTAssertEqual(result.count, 2, "Success argument array length is equal to the number of promises")
            XCTAssertEqual(result[0], 1, "All success argument array is ordered the same as the input promises")
            XCTAssertEqual(result[1], 2, "All success argument array is ordered the same as the input promises")
            foo = result.reduce(foo, combine: { $0 + $1 })
        }).error({ (error) in
            XCTFail("Error handler does not trigger when all child promises succeed")
        }).always({
            foo += 1
        })
        a.resolve(1)
        XCTAssertEqual(foo, 0, "All promise success handler does not execute until after child promises are resolved")
        b.resolve(2)
        XCTAssertEqual(foo, 4, "All promise success and finish handler executes after child promises are resolved")
        foo = 0
        let c = Promise<Int>()
        let d = Promise<Int>()
        let e = Promise<Int>()
        let f = Promise<Int>()
        Promise.all([c, d, e, f]).then({ (result) in
            XCTFail("Success handler does not trigger when one or more child promise errors")
        }).error({ (error) in
            foo += 1
            XCTAssertEqual(foo, 1, "Error handler triggers only once when one or more child promise errors")
            XCTAssertEqual((error as NSError).domain, "example", "Error argument to promise error handler is first failed child promise's error")
        }).always({ () in
            foo += 1
        })
        c.resolve(0)
        d.reject(NSError(domain: "example", code: 0, userInfo: nil))
        XCTAssertEqual(foo, 2, "Error and finish handlers trigger immediately on ALL promise when first child promise fails")
        e.resolve(0)
        f.reject(NSError(domain: "", code: 0, userInfo: nil))
        XCTAssertEqual(foo, 2, "Error and finish handlers trigger only once when one or more child promise errors")
    }
    
    func testConstructor() {
        var foo = 0
        Promise<Int>({ (onSuccess, onError) in
            foo += 1
            onSuccess(foo)
        }).then({ (result) in
            XCTAssertEqual(foo, 1, "Executor constructor executes success argument function immediately")
        }).error({ (error) in
            XCTFail("Error handler not triggered when executor function succeeds")
        })
        XCTAssertEqual(foo, 1, "Executor constructor executes success code")
        foo = 0
        Promise<Int>({ (onSuccess, onError) in
            foo += 1
            onError(NSError(domain: "", code: 0, userInfo: nil))
        }).then({ (result) in
            XCTFail("Success handler not triggered when executor function fails")
        }).error({ (error) in
            XCTAssertEqual(foo, 1, "Executor constructor executes error argument function immediately")
        })
        XCTAssertEqual(foo, 1, "Executor constructor executes error code")
    }
    
    func testRace() {
        var foo = 0
        let a = Promise<Int> { (onSuccess, onError) in
            foo += 1
            onSuccess(1)
        }
        let b = Promise<Int> { (onSuccess, onError) in
            foo += 1
            onSuccess(2)
        }
        Promise<Int>.race([a, b]).then({ (result) in
            foo += 1
            XCTAssertEqual(result, 1, "First promise to succeed is returned as result of race")
        }).error({ (error) in
            XCTFail("Error handler does not trigger in successful race")
        })
        XCTAssertEqual(foo, 3, "All promises in race executed")
        foo = 0
        let c = Promise<Int> { (onSuccess, onError) in
            foo += 1
            onError(NSError(domain: "first", code: 0, userInfo: nil))
        }
        let d = Promise<Int> { (onSuccess, onError) in
            foo += 1
            onSuccess(foo)
        }
        let e = Promise<Int> { (onSuccess, onError) in
            foo += 1
            onError(NSError(domain: "second", code: 0, userInfo: nil))
        }
        Promise<Int>.race([c, d, e]).then({ (result) in
            XCTFail("Success handler does not trigger in error race")
        }).error({ (error) in
            foo += 1
            XCTAssertEqual((error as NSError).domain, "first", "First promise to error is returned as result of race")
        })
        XCTAssertEqual(foo, 4, "All promises in race executed")
    }
    
    func testError() {
        var foo = 0
        Promise<Int>.reject(NSError(domain: "example", code: 0, userInfo: nil)).then({ (result) in
            XCTFail("Success handler does not trigger for auto-error promise")
        }).error({ (error) in
            foo += 1
        })
        XCTAssertEqual(foo, 1, "Error handler triggers immediately for auto-error promise")
    }
    
    func testSuccess() {
        var foo = 0
        Promise<Int>.resolve(1).then({ (result) in
            foo += 1
        }).error({ (error) in
            XCTFail("Error handler does not trigger for auto-success promise")
        })
        XCTAssertEqual(foo, 1, "Success handler triggers immediately for auto-error promise")
    }
    
    func testProgress() {
        let steps = 10
        var percents = [Double]()
        var messages = [String?]()
        let expectation = expectationWithDescription("Iteration completed")
        Promise<Int> { (onSuccess, onError, onProgress) in
            dispatch_async(dispatch_get_main_queue(), {
                for i in 0...steps {
                    onProgress(Double(i) / Double(steps), "\(i)")
                }
                onSuccess(steps)
                expectation.fulfill()
            })
            }.check { (percent, message) in
                percents.append(percent)
                messages.append(message)
            }.then { (total) in
                XCTAssertEqual(percents.count, steps + 1, "Not enough steps captured in progress")
                XCTAssertEqual(messages.count, steps + 1, "Not enough steps captured in progress")
                let anticipatedPercents = (0...steps).map({ Double($0) / Double(steps) })
                let anticipatedMessages = (0...steps).map({ "\($0)" })
                for i in 0 ..< percents.count {
                    XCTAssertEqual(anticipatedPercents[i], percents[i], "Progress percent was not captured correctly")
                    XCTAssertEqual(anticipatedMessages[i], messages[i], "Progress message was not captured correctly")
                }
        }
        waitForExpectationsWithTimeout(5.0, handler: nil)
    }
}
