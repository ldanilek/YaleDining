//
//  DiskManagerMockTests.swift
//  Yale
//
//  Created by Lee on 4/7/17.
//  Copyright © 2017 Yale STC Developers. All rights reserved.
//

/* For each test, creates a promiseResult, and adds the expected value to the disk's expected array and checks if the mock returns the correct value*/ 

import XCTest
@testable import Yale_Dining

class DiskManagerMockTests: XCTestCase {
    let disk = DiskManagerMock()
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testCreateDirectoryAsync() {
        let promiseResult = Promise<Void>()
        disk.expect(method: .createDirectory, args: ["/Users/Shanelle/Desktop/Yale/SophmoreYear/Projects/STCDevelopers/YaleMobile-iOS"], andReturn: promiseResult, fulfill: expectedPromise())
        XCTAssertEqual(disk.createDirectoryAsync(atPath: "/Users/Shanelle/Desktop/Yale/SophmoreYear/Projects/STCDevelopers/YaleMobile-iOS"), promiseResult)
        self.waitForExpectations(timeout: 1)
    }
    
    func testFileExistsAsync() {
        let promiseResult = Promise<(exists: Bool, isDir: Bool)>()
        disk.expect(method: .fileExists, args: ["/Users/Shanelle/Desktop/Yale/SophmoreYear/Projects/STCDevelopers/YaleMobile-iOS/README.md"], andReturn: promiseResult, fulfill: expectedPromise())
        XCTAssertEqual(disk.fileExistsAsync(atPath: "/Users/Shanelle/Desktop/Yale/SophmoreYear/Projects/STCDevelopers/YaleMobile-iOS/README.md"), promiseResult)
        self.waitForExpectations(timeout: 1)
    }
    
    func testWriteData() {
        let promiseResult = Promise<Void>()
        let data = "read this!".data(using: .ascii)
        let url = URL(fileURLWithPath: "/Users/Shanelle/Desktop/Yale/SophmoreYear/Projects/STCDevelopers/YaleMobile-iOS/README.md")
        disk.expect(method: .writeData, args: [data!, url], andReturn: promiseResult, fulfill: expectedPromise())
        XCTAssertEqual(disk.writeData(data!, to: url), promiseResult)
        self.waitForExpectations(timeout: 1)
    }
    
    func testRemoveItemAsync() {
        let promiseResult = Promise<Void>()
        let url = URL(fileURLWithPath: "/Users/Shanelle/Desktop/Yale/SophmoreYear/Projects/STCDevelopers/YaleMobile-iOS/README.md")
        disk.expect(method: .removeItem, args: [url], andReturn: promiseResult, fulfill: expectedPromise())
        XCTAssertEqual(disk.removeItemAsync(at: url), promiseResult)
        self.waitForExpectations(timeout: 1)
    }
    
    func testReadData() {
        let promiseResult = Promise<Data>()
        let url = URL(fileURLWithPath: "/Users/Shanelle/Desktop/Yale/SophmoreYear/Projects/STCDevelopers/YaleMobile-iOS/README.md")
        disk.expect(method: .readData, args: [url], andReturn: promiseResult, fulfill: expectedPromise())
        XCTAssertEqual(disk.readData(contentsOf: url), promiseResult)
        self.waitForExpectations(timeout: 1)
    }
}
