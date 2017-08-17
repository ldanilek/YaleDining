//
//  DiskManager.swift
//  Yale
//
//  Created by Lee on 4/7/17.
//  Copyright © 2017 Yale STC Developers. All rights reserved.
//

import UIKit

protocol DiskManager {
    func createDirectoryAsync(atPath path: String) -> Promise<Void>
    func removeItemAsync(at URL: URL) -> Promise<Void>
    func readData(contentsOf URL: URL) -> Promise<Data>
    func writeData(_ data: Data, to url: URL) -> Promise<Void>
    func fileExistsAsync(atPath path: String) -> Promise<(exists: Bool, isDir: Bool)>
}

let fileSystemQueue = DispatchQueue(label: "file_system.sdmp.yale")

class StandardDiskManager: NSObject, DiskManager {
    let fileManager = FileManager.default
    func createDirectoryAsync(atPath path: String) -> Promise<Void> {
        return Promise(withQueue: fileSystemQueue) {
            try self.fileManager.createDirectory(atPath: path, withIntermediateDirectories: false, attributes: nil)
            return .Value()
        }
    }
    func removeItemAsync(at URL: URL) -> Promise<Void> {
        return Promise(withQueue: fileSystemQueue) {
            try self.fileManager.removeItem(at: URL)
            return .Value()
        }
    }
    func readData(contentsOf URL: URL) -> Promise<Data> {
        return Promise(withQueue: fileSystemQueue) {
            return .Value(try Data(contentsOf: URL))
        }
    }
    func writeData(_ data: Data, to url: URL) -> Promise<Void> {
        return Promise(withQueue: fileSystemQueue) {
            try data.write(to: url)
            return .Value()
        }
    }
    func fileExistsAsync(atPath path: String) -> Promise<(exists: Bool, isDir: Bool)> {
        return Promise(withQueue: fileSystemQueue) {
            var isDir = ObjCBool(false)
            let exists = self.fileManager.fileExists(atPath: path, isDirectory: &isDir)
            return .Value(exists: exists, isDir: isDir.boolValue)
        }
    }
}
