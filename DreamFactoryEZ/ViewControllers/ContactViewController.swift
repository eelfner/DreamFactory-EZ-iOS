//
//  ViewController.swift
//  DreamFactoryEZ
//
//  Created by Eric Elfner on 2016-05-03.
//  Copyright © 2016 Eric Elfner. All rights reserved.
//

import UIKit

class ContactViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, ContactDetailDelegate, ContactUpdateDelegate {

    let kEditAddressSegue = "EditAddressSegue"
    let kEditContactSegue = "EditContactSegue"
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var contactImageView: UIImageView!
    @IBOutlet weak var contactFullNameLabel: UILabel!
    @IBOutlet weak var contactSkypeLabel: UILabel!
    @IBOutlet weak var contactTwitterLabel: UILabel!
    @IBOutlet weak var contactNotesLabel: UILabel!
    
    @IBOutlet weak var editImageButton: UIButton!
    @IBOutlet weak var editNameButton: UIButton!
    
    private let kAddressCell = "AddressCell"
    private let kGroupCell = "GroupCell"
    private let dataAccess = DataAccess.sharedInstance

    var contact: ContactRecord?
    private var groups = [GroupRecord]()
    private var details = [ContactDetailRecord]()
    private var bIsEditMode = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view, typically from a nib.
        contactImageView.image = UIImage(named: "default_portrait")
        contactFullNameLabel.text = nil
        contactSkypeLabel.text = nil
        contactTwitterLabel.text = nil
        contactNotesLabel.text = nil
        
        configureTableView()
        setupForView()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(activityChanged), name: kRESTServerActiveCountUpdated, object: nil)
        
    }
    override func viewDidAppear(animated: Bool) {
        if dataAccess.isSignedIn() {
            updateContact()
            if let id = contact?.id {
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
    
    private func setupForView() {
        bIsEditMode = false
        self.navigationItem.setLeftBarButtonItem(nil, animated: false);
        
        let rightMenuItem = UIBarButtonItem(barButtonSystemItem: .Edit, target: self, action: #selector(editSelected))
        self.navigationItem.setRightBarButtonItem(rightMenuItem, animated: false);
        
        editImageButton.hidden = true
        editNameButton.hidden = true
        
        tableView.allowsSelection = false
        tableView.reloadData()
    }
    private func setupForEdit() {
        bIsEditMode = true
        self.navigationItem.setLeftBarButtonItem(nil, animated: false);
        let rightMenuItem = UIBarButtonItem(barButtonSystemItem: .Done, target: self, action: #selector(saveSelected))
        self.navigationItem.setRightBarButtonItem(rightMenuItem, animated: false);
        
        editImageButton.hidden = false
        editNameButton.hidden = false
        
        tableView.allowsSelection = true
        tableView.reloadData()
    }
    
    
    @objc func editSelected() {
        setupForEdit()
    }
    @objc func saveSelected() {
        // Do Save
        setupForView()
    }
    @objc func cancelSelected() {
        setupForView()
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

    @IBAction func editAction() {
        performSegueWithIdentifier(kEditContactSegue, sender: self)
    }
    @IBAction func editImageAction() {
    }
    private func updateContact() {
        contactImageView.image = UIImage(named: "default_portrait")
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
    
    // MARK: ContactUpdateDelegate
    
    func setContact(contact:ContactRecord) {
        self.contact = contact
        updateContact()
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
        case 0: return bIsEditMode ? details.count + 1 : details.count
        case 1: return bIsEditMode ? dataAccess.allGroups.count : groups.count
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
            if iDetail == details.count {
                // Edit mode, new Address
                cell.typeLabel.text = "NEW"
                cell.addressLabel.text = "(Add new Address)"
                cell.accessoryType = .DisclosureIndicator
            }
            else {
            let detail = details[iDetail]
                cell.typeLabel.text = detail.type
                cell.addressLabel.text = detail.description
                cell.accessoryType = bIsEditMode ? .DisclosureIndicator : .None
            }
        }
        
        return cell!
    }
    private func cellForGroupAtIndex(iGroup:Int) -> UITableViewCell {
        var cell = tableView.dequeueReusableCellWithIdentifier(kGroupCell)
        if (cell == nil) {
            cell = UITableViewCell(style: .Default, reuseIdentifier: kGroupCell)
        }
        if bIsEditMode {
            let groupName = dataAccess.allGroups[iGroup].name
            cell?.textLabel?.text = groupName
            let bIsForUser = userHasGroupName(groupName)
            cell?.accessoryType = bIsForUser ? .Checkmark : .None
        }
        else {
            cell?.textLabel?.text = groups[iGroup].name
            cell?.accessoryType = .Checkmark
        }
        return cell!
    }
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        var bCanEdit = false
        if indexPath.section == 0 && bIsEditMode {
            bCanEdit = true
        }
        return bCanEdit
    }
    // MARK: UITableViewDelegate
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        guard bIsEditMode else { return }
        
        if indexPath.section == 0 {
            performSegueWithIdentifier(kEditAddressSegue, sender: self)
        }
        else {
            if let contact = contact {
                let selectedGroup = dataAccess.allGroups[indexPath.row]
                let bHasGroup = userHasGroupName(selectedGroup.name)
                if bHasGroup {
                    dataAccess.removeContact(contact, fromGroupId: selectedGroup.id, resultDelegate: self)
                }
                else {
                    dataAccess.addContact(contact, toGroupId: selectedGroup.id, resultDelegate: self)
                }
            }
        }
    }
    private func userHasGroupName(groupName:String) -> Bool {
        let bHasGroup = groups.contains({ (g) -> Bool in g.name == groupName })
        return bHasGroup
    }
    
    // MARK: Segue
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == kEditAddressSegue {
            if let vc = segue.destinationViewController as? AddressEditViewController {
                if let contact = contact, row = tableView.indexPathForSelectedRow?.row {
                    vc.contact = contact
                    vc.contactDetailDelegate = self
                    if row == details.count {
                        vc.address = ContactDetailRecord(contactId: contact.id)
                    }
                    else {
                        vc.address = details[row]
                    }
                }
            }
        }
        else if segue.identifier == kEditContactSegue {
            if let vc = segue.destinationViewController as? ContactEditViewController {
                if let contact = contact {
                    vc.contact = contact
                    vc.updatedContactDelegate = self
                }
            }
        }
    }
}




















