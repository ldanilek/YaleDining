//
//  HallListTableViewController.swift
//  Yale Dining
//
//  Created by Lee on 8/16/17.
//  Copyright © 2017 Yale SDMP. All rights reserved.
//

import UIKit

class HallListTableViewController: UITableViewController {
    
    let model = Model.default
    var locations = [Location]()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Not sure of the best way to do this
        let promise: Promise<[Location]>
        if self.tableView.tag == 0 {
            promise = model.residentialHalls()
        } else {
            promise = model.retailOutlets()
        }
        promise.onKeep(withQueue: DispatchQueue.main, { (locations) in
            self.locations = locations
            self.tableView.reloadData()
        }).onRenege { (err) -> Void in
            let alert = UIAlertController(title: "Error loading dining halls", message: err.localizedDescription, preferredStyle: .alert)
            self.present(alert, animated: true)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.locations.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "hall_cell", for: indexPath)
        let location = self.locations[indexPath.row]
        cell.textLabel?.text = location.name
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.performSegue(withIdentifier: "location_detail", sender: indexPath)
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let index = (sender as? IndexPath)?.row else {
            return
        }
        guard let menu = segue.destination as? MenuTableViewController else {
            return
        }
        let location = self.locations[index]
        menu.locationId = location.id
        menu.locationName = location.name
    }

}
