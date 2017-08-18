//
//  MapViewController.swift
//  Yale Dining
//
//  Created by Lee on 8/17/17.
//  Copyright © 2017 Yale SDMP. All rights reserved.
//

import UIKit
import MapKit

class LocationAnnotation: NSObject, MKAnnotation {

    let location: Location
    init(location: Location) {
        self.location = location
    }
    
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: location.coords.0, longitude: location.coords.1)
    }

    var title: String? {
        return self.location.name
    }
}

func standardDeviation(arr : [Double]) -> Double
{
    let length = Double(arr.count)
    let avg = arr.reduce(0, +) / length
    let sumOfSquaredAvgDiff = arr.map { pow($0 - avg, 2.0)}.reduce(0, +)
    return sqrt(sumOfSquaredAvgDiff / length)
}

func average(arr: [Double]) -> Double {
    return arr.reduce(0, +) / Double(arr.count)
}

class MapViewController: UIViewController {
    
    var model = Model.default
    
    func zoomOnLocations(_ locations: [CLLocationCoordinate2D]) {
        guard locations.count > 0 else {
            return
        }
        var longitudes = locations.map { (location) -> CLLocationDegrees in
            return location.longitude
        }
        var latitudes = locations.map { (location) -> CLLocationDegrees in
            return location.latitude
        }
        // ignore locations that are too far away from the center
        let ZSCORE = 2.0
        longitudes = longitudes.filter({ (lng) -> Bool in
            return abs(lng - average(arr: longitudes)) < ZSCORE * standardDeviation(arr: longitudes)
        })
        latitudes = latitudes.filter({ (lat) -> Bool in
            return abs(lat - average(arr: latitudes)) < ZSCORE * standardDeviation(arr: latitudes)
        })
        // leave some room around the locations
        let PADDING = 0.001
        let minLng = longitudes.min()! - PADDING
        let maxLng = longitudes.max()! + PADDING
        let minLat = latitudes.min()! - PADDING
        let maxLat = latitudes.max()! + PADDING
        let span = MKCoordinateSpanMake(maxLat - minLat,  maxLng - minLng)
        let middle = CLLocationCoordinate2D(latitude: (maxLat + minLat)/2, longitude: (maxLng + minLng)/2)
        let coordinateRegion = MKCoordinateRegionMake(middle, span)
        self.mapView.setRegion(coordinateRegion, animated: true)
    }
    
    func annotation(forLocation location: Location) -> MKAnnotation {
        return LocationAnnotation(location: location)
    }

    @IBOutlet weak var mapView: MKMapView!
    override func viewDidLoad() {
        super.viewDidLoad()
        let promise = model.allLocations()
        promise.onKeep(withQueue: DispatchQueue.main, { (locations) -> Void in
            self.zoomOnLocations(locations.map({ (location) -> CLLocationCoordinate2D in CLLocationCoordinate2D(latitude: location.coords.0, longitude: location.coords.1) }))
            self.mapView.addAnnotations(locations.map({ (location) -> MKAnnotation in
                return self.annotation(forLocation: location)
            }))
        })
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
