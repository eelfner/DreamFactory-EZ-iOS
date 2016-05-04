//
//  ViewController.swift
//  DreamFactoryEZ
//
//  Created by Eric Elfner on 2016-05-03.
//  Copyright © 2016 Eric Elfner. All rights reserved.
//

import UIKit

class ContactsViewController: UITableViewController {

    private let kCellID = "CellID"
    
    //private var names = [String]()
    private var names = ["One", "Two", "Three"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
    }
    
    override func viewWillAppear(animated: Bool) {
        API.sharedInstance.getContacts(nil) { (restResult) in
            if restResult.bIsSuccess {
                //print("Result \(restResult.json)")
                var newNames = [String]()
                if let contactsArray = restResult.json?["resource"] as? JSONArray {
                    for contact in contactsArray {
                        if let fName = contact["first_name"], let lName = contact["last_name"] {
                            let name = "\(lName), \(fName)"
                            newNames.append(name)
                            newNames.sortInPlace()
                        }
                    }
                }
                dispatch_async(dispatch_get_main_queue()) {
                    self.names = newNames
                    self.tableView.reloadData()
                }
                
            }
            else {
                print("Error \(restResult.error)")
            }
            
        }
    }
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    // MARK: UITableViewDataSource
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return names.count
    }
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCellWithIdentifier(kCellID)
        
        if (cell == nil) {
            cell = UITableViewCell(style: .Default, reuseIdentifier: kCellID)
        }
        cell!.textLabel?.text = names[indexPath.row]
        return cell!
    }
}