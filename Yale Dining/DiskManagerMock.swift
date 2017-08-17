//
//  DiskManagerMock.swift
//  Yale
//
//  Created by Lee on 4/7/17.
//  Copyright © 2017 Yale STC Developers. All rights reserved.
//

/**
 * Disk manager mock class, used in testing to mimic the functionality of the disk manager.
 * DiskMethod enum lists the different methods that the disk manager implements.
 * The comments to describe the arguments the corresponding function takes and its return value.
 * The mock returns a promise for each of the functions that the disk manager implements,
 * using the expected array to keep track of what should be passed in and returned
 * See the DiskManagerMockTests for how it's used.
 * Not thread safe. Only call from a single thread.
 */

import UIKit

public enum DiskMethod {
    case createDirectory // [String] -> Promise<Void>
    case fileExists // [String] -> Promise<(exists: Bool, isDir: Bool)>
    case writeData // [Data, URL] -> Promise<Void>
    case removeItem // [URL] -> Promise<Void>
    case readData // [URL] -> Promise<Data>
}

class DiskManagerMock: NSObject, DiskManager {

    // Stores FIFO expectations, so when you expect 3 things to happen they must happen in that order.
    // each expectation is a method, arguments, the return value, and a promise to be kept when the method is called.
    private var expected = [(method: DiskMethod, args: [Any], retVal: Any, fulfill: Promise<Void>)]()
    
    func expect<T>(method: DiskMethod, args: [Any], andReturn retVal: Promise<T>, fulfill: Promise<Void>) {
        self.expected.append((method, args, retVal as Any, fulfill))
    }
    
    func createDirectoryAsync(atPath path: String)  -> Promise<Void> {
        let expect = expected.removeFirst()
        assert(expect.method == .createDirectory)
        let args = expect.args
        assert(args[0] as! String == path)
        expect.fulfill.keep(withValue: ())
        return expect.retVal as! Promise
    }
    
    func fileExistsAsync(atPath path: String) -> Promise<(exists: Bool, isDir: Bool)> {
        let expect = expected.removeFirst()
        assert(expect.method == .fileExists)
        
        let args = expect.args
        assert(args[0] as! String == path)
        expect.fulfill.keep(withValue: ())
        return expect.retVal as! Promise<(exists: Bool, isDir: Bool)>
    }
    
    func writeData(_ data: Data, to url: URL) -> Promise<Void> {
        let expect = expected.removeFirst()
        assert(expect.method == .writeData)
        let args = expect.args
        assert(args[0] as! Data == data)
        assert(args[1] as! URL == url)
        expect.fulfill.keep(withValue: ())
        return expect.retVal as! Promise
    }

    func removeItemAsync(at URL: URL) -> Promise<Void> {
        let expect = expected.removeFirst()
        assert(expect.method == .removeItem)
        let args = expect.args
        assert(args[0] as! URL == URL)
        expect.fulfill.keep(withValue: ())
        return expect.retVal as! Promise
    }
    
    func readData(contentsOf URL: URL) -> Promise<Data> {
        let expect = expected.removeFirst()
        assert(expect.method == .readData)
        let args = expect.args
        assert(args[0] as! URL == URL)
        expect.fulfill.keep(withValue: ())
        return expect.retVal as! Promise<Data>
    }
}
