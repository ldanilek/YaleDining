//
//  Model.swift
//  Yale Dining
//
//  Created by Lee on 8/16/17.
//  Copyright © 2017 Yale SDMP. All rights reserved.
//

import UIKit

/**
 * Entry point for retrieving data.
 * Stateless.
 */


struct Location {
    let id: Int
    let name: String
    let type: LocationType
    let capacity: Int
    let coords: (Double, Double)
    let closed: Bool
    let address: String
    let phone: String
    let managers: [(name: String, email: String)]
}

struct MenuItem {
    let mealName: String
    let menuDate: Date
    let name: String
    let id: Int
    let locationName: String
}

enum LocationType {
    case Residential
    case Retail
}

let BASE_URL = NSURL(string: "http://www.yaledining.org/fasttrack/")!

func err(msg: String) -> NSError {
    return NSError(domain: "Model", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
}

// the Dining API returns the data in an odd way
func reformedData(_ jsonData: Any) throws -> Array<Dictionary<String, Any>> {
    guard let d = jsonData as? NSDictionary else {
        throw err(msg: "API did provide a dictionary")
    }
    guard let cols = d["COLUMNS"] as? [String] else {
        throw err(msg: "API did not have COLUMNS key")
    }
    guard let data = d["DATA"] as? [[Any]] else {
        throw err(msg: "API did not have DATA key")
    }
    var reformed = [[String: Any]]()
    for dataPoint in data {
        var reformedDataPoint = [String: Any]()
        for (index, colTitle) in cols.enumerated() {
            reformedDataPoint[colTitle] = dataPoint[index]
        }
        reformed.append(reformedDataPoint)
    }
    return reformed
}

func parseCoords(_ coords: String?) throws -> (Double, Double) {
    guard let parts = coords?.components(separatedBy: ","), parts.count == 2 else {
        throw err(msg: "GEOLOCATION must have a single comma")
    }
    return (NSString(string: parts[0]).doubleValue, NSString(string: parts[1]).doubleValue)
}

func parseLocation(_ dict: [String: Any]) throws -> Location {
    guard let id = (dict["ID_LOCATION"] as? NSNumber)?.intValue else {
        throw err(msg: "ID_LOCATION must be an integer")
    }
    guard let capacity = dict["CAPACITY"] is NSNull ? 0 : (dict["CAPACITY"] as? NSNumber)?.intValue else {
        throw err(msg: "CAPACITY must be an integer")
    }
    guard let address = dict["ADDRESS"] as? String else {
        throw err(msg: "ADDRESS must be a string")
    }
    guard let phone = dict["PHONE"] as? String else {
        throw err(msg: "PHONE must be a string")
    }
    guard let typeStr = dict["TYPE"] as? String, typeStr == "Residential" || typeStr == "Retail" else {
        throw err(msg: "TYPE must be Residential or Retail")
    }
    let type: LocationType = typeStr == "Residential" ? .Residential : .Retail
    guard let name = dict["DININGLOCATIONNAME"] as? String else {
        throw err(msg: "DININGLOCATIONNAME must be a string")
    }
    let coords = try parseCoords(dict["GEOLOCATION"] as? String)
    guard let isClosed = (dict["ISCLOSED"] as? NSNumber)?.intValue, isClosed == 1 || isClosed == 0 else {
        throw err(msg: "ISCLOSED must be 0 or 1")
    }
    var managers = [(name: String, email: String)]()
    for managerIndex in 1...4 {
        if dict["MANAGER\(managerIndex)NAME"] is NSNull {
            continue
        }
        guard let managerName = dict["MANAGER\(managerIndex)NAME"] as? String else {
            throw err(msg: "MANAGER\(managerIndex)NAME must be string")
        }
        guard let managerEmail = dict["MANAGER\(managerIndex)EMAIL"] as? String else {
            throw err(msg: "MANAGER\(managerIndex)EMAIL must be string")
        }
        managers.append((name: managerName, email: managerEmail))
    }
    
    return Location(id: id, name: name, type: type, capacity: capacity, coords: coords, closed: isClosed == 1, address: address, phone: phone, managers: managers)
}

func parseMenuItem(_ dict: [String: Any]) throws -> MenuItem {
    guard let mealName = dict["MEALNAME"] as? String else {
        throw err(msg: "MEALNAME must be a string")
    }
    guard let id = (dict["MENUITEMID"] as? NSNumber)?.intValue else {
        throw err(msg: "MENUITEMID must be an int")
    }
    guard let name = dict["MENUITEM"] as? String else {
        throw err(msg: "MENUITEM must be a string")
    }
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM, DD YY hh:mm:ss"
    guard let s = dict["MENUDATE"] as? String, let menuDate = formatter.date(from: s) else {
        throw err(msg: "MENUDATE must be a date")
    }
    guard let locationName = dict["LOCATION"] as? String else {
        throw err(msg: "LOCATION must be a string")
    }
    return MenuItem(mealName: mealName, menuDate: menuDate, name: name, id: id, locationName: locationName)
}

class Model: NSObject {
    static let `default` = Model()
    var portal = CachedAPIPortal.default
    
    func endpoint(name: String, arguments: [String: String] = [:]) -> URL {
        let components = NSURLComponents(url: BASE_URL.appendingPathComponent(name + ".cfm")!, resolvingAgainstBaseURL: false)!
        var queryItems = [URLQueryItem(name: "version", value: "3")]
        for (key, arg) in arguments {
            queryItems.append(URLQueryItem(name: key, value: arg))
        }
        components.queryItems = queryItems
        return components.url!
    }
    
    lazy var locationsURL: URL = {
        return self.endpoint(name: "locations")
    }()
    
    func menuURL(forLocation id: Int) -> URL {
        return self.endpoint(name: "menus", arguments: ["location": "\(id)"])
    }
    
    func allLocations() -> Promise<[Location]> {
        // cache for a week
        // parse it in stages
        return portal.fetch(url: locationsURL,
                            cacheTTL: 7 * 24 * 60 * 60)
            .onKeep({ (data) -> PromiseResult<[[String: Any]]> in
                return .Value(try reformedData(try JSONSerialization.jsonObject(with: data)))
            })
            .onKeep({ (data) -> PromiseResult<[Location]> in
                var locations = [Location]()
                for dict in data {
                    locations.append(try parseLocation(dict))
                }
                return .Value(locations)
            })
    }
    
    public func menu(forLocationId id: Int) -> Promise<[MenuItem]> {
        return portal.fetch(url: menuURL(forLocation: id), cacheTTL: 24 * 60 * 60)
            .onKeep({ (data) -> PromiseResult<[[String: Any]]> in
                return .Value(try reformedData(try JSONSerialization.jsonObject(with: data)))
            })
            .onKeep({ (data) -> PromiseResult<[MenuItem]> in
                var menu = [MenuItem]()
                for dict in data {
                    menu.append(try parseMenuItem(dict))
                }
                return .Value(menu)
            })
    }

    public func residentialHalls() -> Promise<[Location]> {
        return allLocations().onKeep({ (locations) -> PromiseResult<[Location]> in
            return .Value(locations.filter({ (location) -> Bool in
                location.type == .Residential
            }))
        })
    }
    
    public func retailOutlets() -> Promise<[Location]> {
        return allLocations().onKeep({ (locations) -> PromiseResult<[Location]> in
            return .Value(locations.filter({ (location) -> Bool in
                location.type == .Retail
            }))
        })
    }
}
