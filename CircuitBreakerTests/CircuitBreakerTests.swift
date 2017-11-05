import XCTest
@testable import CircuitBreaker

class CircuitBreakerTests: XCTestCase {
    
    private var testService: TestService!
    private var circuitBreaker: CircuitBreaker!
    
    override func setUp() {
        super.setUp()
        
        testService = TestService()
    }
    
    override func tearDown() {
        circuitBreaker.reset()
        circuitBreaker.didTrip = nil
        circuitBreaker.call = nil
        
        super.tearDown()
    }
    
    func testSuccess() {
        let expect = expectation(description: "Successful call")
        
        circuitBreaker = CircuitBreaker()
        circuitBreaker.call = { [weak self] circuitBreaker in
            self?.testService.successCall { data, error in
                XCTAssertNotNil(data)
                XCTAssertNil(error)
                circuitBreaker.success()
                expect.fulfill()
            }
        }
        circuitBreaker.execute()
        
        waitForExpectations(timeout: 10) { _ in }
    }
    
    func testTimeout() {
        let expect = expectation(description: "Timed out call")
        
        circuitBreaker = CircuitBreaker(timeout: 3.0)
        circuitBreaker.call = { [weak self] circuitBreaker in
            switch circuitBreaker.failureCount {
            case 0:
                self?.testService?.delayedCall(5) { _, _ in }
            default:
                self?.testService?.successCall { data, error in
                    circuitBreaker.success()
                    expect.fulfill()
                }
            }
        }
        circuitBreaker.execute()
        
        waitForExpectations(timeout: 115) { _ in }
    }
    
    func testFailure() {
        let expect = expectation(description: "Failure call")
        
        circuitBreaker = CircuitBreaker(timeout: 10.0, maxRetries: 1)
        circuitBreaker.call = { [weak self] circuitBreaker in
            switch circuitBreaker.failureCount {
            case 0:
                self?.testService?.failureCall { data, error in
                    XCTAssertNil(data)
                    XCTAssertNotNil(error)
                    circuitBreaker.failure()
                }
            default:
                self?.testService?.successCall { data, error in
                    circuitBreaker.success()
                    expect.fulfill()
                }
            }
        }
        circuitBreaker.execute()
        
        waitForExpectations(timeout: 110) { _ in }
    }
    
    func testTripping() {
        let expect = expectation(description: "Tripped call")
        
        circuitBreaker = CircuitBreaker(
            timeout: 10.0,
            maxRetries: 2,
            timeBetweenRetries: 1.0,
            exponentialBackoff: false,
            resetTimeout: 2.0
        )
        
        circuitBreaker.didTrip = { circuitBreaker, error in
            XCTAssertTrue(circuitBreaker.state == .open)
            XCTAssertTrue(circuitBreaker.failureCount == circuitBreaker.maxRetries + 1)
            XCTAssertTrue((error! as NSError).code == 404)
            circuitBreaker.reset()
            expect.fulfill()
        }
        circuitBreaker.call = { [weak self] circuitBreaker in
            self?.testService.failureCall { data, error in
                circuitBreaker.failure(NSError(domain: "TestService", code: 404, userInfo: nil))
            }
        }
        circuitBreaker.execute()
        
        waitForExpectations(timeout: 1100) { error in
            print(error!)
        }
    }
    
    func testReset() {
        let expect = expectation(description: "Reset call")
        
        circuitBreaker = CircuitBreaker(
            timeout: 10.0,
            maxRetries: 1,
            timeBetweenRetries: 1.0,
            exponentialBackoff: false,
            resetTimeout: 2.0
        )
        circuitBreaker.call = { [weak self] circuitBreaker in
            if circuitBreaker.state == .halfOpen {
                self?.testService?.successCall { data, error in
                    circuitBreaker.success()
                    XCTAssertTrue(circuitBreaker.state == .closed)
                    expect.fulfill()
                }
                return
            }
            
            self?.testService.failureCall { data, error in
                circuitBreaker.failure()
            }
        }
        circuitBreaker.execute()

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()) {
            self.circuitBreaker.execute()
        }
        
        waitForExpectations(timeout: 110) { _ in }
    }
    
}


