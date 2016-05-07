//
//  ViewController.swift
//  DreamFactoryEZ
//
//  Created by Eric Elfner on 2016-05-03.
//  Copyright © 2016 Eric Elfner. All rights reserved.
//

import UIKit

class ContactViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, ContactDetailDelegate {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    private let kAddressCell = "AddressCell"
    private let kGroupCell = "GroupCell"
    private let dataAccess = DataAccess.sharedInstance

    var contact: ContactRecord?
    private var groups = [GroupRecord]()
    private var details = [ContactDetailRecord]()
    private var bIsEditing = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(activityChanged), name: kRESTServerActiveCountUpdated, object: nil)
    }
    
    override func viewDidAppear(animated: Bool) {
        if dataAccess.isSignedIn() {
            //dataAccess.getGroups(nil, resultDelegate: self)
        }
        else {
            navigationController?.popToRootViewControllerAnimated(true)
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    @objc func activityChanged(notification:NSNotification) {
        let activityCount = (notification.userInfo?["count"] as? NSNumber)?.longValue ?? 0
        if activityCount > 0 {
            activityIndicator.startAnimating()
        }
        else {
            activityIndicator.stopAnimating()
        }
    }

    @IBAction func groupsAction() {
        performSegueWithIdentifier("GroupsSegue", sender: self)
    }
    
    // MARK: ContactDelegate
    func setContactGroups(groups: [GroupRecord]) {
        self.groups = groups
        self.tableView.reloadSections(NSIndexSet(), withRowAnimation: .Fade)
    }
    func setContactDetails(details: [ContactDetailRecord]) {
        self.details = details
        self.tableView.reloadSections(NSIndexSet(), withRowAnimation: .Fade)
    }
    func dataAccessError(error: NSError?) {
        if let error = error {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    // MARK: UITableViewDataSource
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Address"
        case 1: return "Groups"
        default: return nil
        }
    }
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return details.count
        case 1: return groups.count
        default: return 0
        }
    }
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            return cellForDetailAtIndex(indexPath.row)
        }
        else {
            return cellForGroupAtIndex(indexPath.row)
        }
    }
    private func cellForDetailAtIndex(iDetail:Int) -> UITableViewCell {
        var cell = tableView.dequeueReusableCellWithIdentifier(kAddressCell)
        if (cell == nil) {
            cell = UITableViewCell(style: .Default, reuseIdentifier: kAddressCell)
        }
        return cell!
    }
    private func cellForGroupAtIndex(iGroup:Int) -> UITableViewCell {
        var cell = tableView.dequeueReusableCellWithIdentifier(kGroupCell)
        if (cell == nil) {
            cell = UITableViewCell(style: .Default, reuseIdentifier: kGroupCell)
        }
        return cell!
    }
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    }
}




















