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
        
        let leftMenuItem = UIBarButtonItem(barButtonSystemItem: .Organize, target: self, action: #selector(settingsSelected))
        self.navigationItem.setLeftBarButtonItem(leftMenuItem, animated: false);
        
        // Notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(newContactNames), name: kNotificationContactNames, object: nil)
    }
    override func viewWillAppear(animated: Bool) {
        //API.sharedInstance.getContactNames()
    }
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    @objc func settingsSelected() {
        
    }
    @objc func newContactNames(notification:NSNotification) {
        if let newNames = notification.object as? [String] {
            names = newNames
            tableView.reloadData()
        }
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