//
//  MenuTableViewController.swift
//  Yale Dining
//
//  Created by Lee on 8/17/17.
//  Copyright © 2017 Yale SDMP. All rights reserved.
//

import UIKit

class MenuTableViewController: UITableViewController {
    
    var locationId: Int = 0
    var locationName: String? = nil
    
    var menu = [MenuItem]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = self.locationName
        let promise = Model.default.menu(forLocationId: locationId)
        promise.onKeep(withQueue: DispatchQueue.main, { (menu) in
            self.menu = menu
            self.tableView.reloadData()
        }).onRenege { (err) -> Void in
            let alert = UIAlertController(title: "Error loading menu", message: err.localizedDescription, preferredStyle: .alert)
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
        return menu.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "menu_cell", for: indexPath)
        let menuItem = self.menu[indexPath.row]
        cell.textLabel?.text = menuItem.name
        if menuItem.id != nil {
            cell.accessoryType = .disclosureIndicator
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        let menuItem = self.menu[indexPath.row]
        return menuItem.id != nil
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
