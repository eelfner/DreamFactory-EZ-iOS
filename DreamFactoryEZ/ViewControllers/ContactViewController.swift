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
    
    @IBOutlet weak var contactImageView: UIImageView!
    @IBOutlet weak var contactFullNameLabel: UILabel!
    @IBOutlet weak var contactSkypeLabel: UILabel!
    @IBOutlet weak var contactTwitterLabel: UILabel!
    @IBOutlet weak var contactNotesLabel: UILabel!
    
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
        contactImageView.image = UIImage(named: "backgroundPerson")
        contactFullNameLabel.text = nil
        contactSkypeLabel.text = nil
        contactTwitterLabel.text = nil
        contactNotesLabel.text = nil
        configureTableView()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(activityChanged), name: kRESTServerActiveCountUpdated, object: nil)
    }
    override func viewDidAppear(animated: Bool) {
        if dataAccess.isSignedIn() {
            updateContact()
            if let id = contact?.id as? Int {
                dataAccess.getContactDetails(id, resultDelegate: self)
            }
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

    private func updateContact() {
        contactImageView.image = UIImage(named: "backgroundPerson")
        contactFullNameLabel.text = contact?.fullName
        contactSkypeLabel.text = contact?.skype
        contactTwitterLabel.text = contact?.twitter
        contactNotesLabel.text = contact?.notes
        
        // Request image [nicer use AFNetworking imageView.setImageWithURLRequest(request ...]
        if let image = contact?.imageURL, imageUrl = NSURL(string: image) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                let imageData = NSData(contentsOfURL: imageUrl)
                if let data = imageData {
                    dispatch_async(dispatch_get_main_queue(), {
                        if let image = UIImage(data: data) {
                            self.contactImageView.image = image
                        }
                    })
                }
            })
        }
    }
    // MARK: TableView Helpers
    func configureTableView() {
        tableView.rowHeight = UITableViewAutomaticDimension // Dynamic sizing
        tableView.estimatedRowHeight = 160.0
    }
    
    // MARK: ContactDetailDelegate
    
    func setContactGroups(groups: [GroupRecord]) {
        self.groups = groups
        //self.tableView.reloadSections(NSIndexSet(), withRowAnimation: .Fade)
        self.tableView.reloadData()
    }
    func setContactDetails(details: [ContactDetailRecord]) {
        self.details = details
        //self.tableView.reloadSections(NSIndexSet(), withRowAnimation: .Fade)
        self.tableView.reloadData()
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
        case 0: return "Addresses"
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
            cell = DetailTableViewCell(style: .Default, reuseIdentifier: kAddressCell)
        }
        if let cell = cell as? DetailTableViewCell {
            let detail = details[iDetail]
            cell.typeLabel.text = detail.type
            cell.addressLabel.text = detail.description
        }
        
        return cell!
    }
    private func cellForGroupAtIndex(iGroup:Int) -> UITableViewCell {
        var cell = tableView.dequeueReusableCellWithIdentifier(kGroupCell)
        if (cell == nil) {
            cell = UITableViewCell(style: .Default, reuseIdentifier: kGroupCell)
        }
        cell?.textLabel?.text = groups[iGroup].name
        return cell!
    }
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    }
}




















