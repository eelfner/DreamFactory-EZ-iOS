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
    
    fileprivate let kAddressCell = "AddressCell"
    fileprivate let kGroupCell = "GroupCell"
    fileprivate let dataAccess = DataAccess.sharedInstance

    var contact: ContactRecord?
    fileprivate var groups = [GroupRecord]()
    fileprivate var details = [ContactDetailRecord]()
    fileprivate var bIsEditMode = false
    
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
        
        NotificationCenter.default.addObserver(self, selector: #selector(activityChanged), name: NSNotification.Name(rawValue: kRESTServerActiveCountUpdated), object: nil)
        
    }
    override func viewDidAppear(_ animated: Bool) {
        if dataAccess.isSignedIn() {
            updateContact()
            if let id = contact?.id {
                dataAccess.getContactDetails(id, resultDelegate: self)
            }
        }
        else {
            _ = navigationController?.popToRootViewController(animated: true)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    fileprivate func setupForView() {
        bIsEditMode = false
        self.navigationItem.setLeftBarButton(nil, animated: false);
        
        let rightMenuItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(editSelected))
        self.navigationItem.setRightBarButton(rightMenuItem, animated: false);
        
        editImageButton.isHidden = true
        editNameButton.isHidden = true
        
        tableView.allowsSelection = false
        tableView.reloadData()
    }
    fileprivate func setupForEdit() {
        bIsEditMode = true
        self.navigationItem.setLeftBarButton(nil, animated: false);
        let rightMenuItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(saveSelected))
        self.navigationItem.setRightBarButton(rightMenuItem, animated: false);
        
        editImageButton.isHidden = false
        editNameButton.isHidden = false
        
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

    @objc func activityChanged(_ notification:Notification) {
        let activityCount = ((notification as NSNotification).userInfo?["count"] as? NSNumber)?.intValue ?? 0
        if activityCount > 0 {
            activityIndicator.startAnimating()
        }
        else {
            activityIndicator.stopAnimating()
        }
    }

    @IBAction func editAction() {
        performSegue(withIdentifier: kEditContactSegue, sender: self)
    }
    @IBAction func editImageAction() {
    }
    fileprivate func updateContact() {
        contactImageView.image = UIImage(named: "default_portrait")
        contactFullNameLabel.text = contact?.fullName
        contactSkypeLabel.text = contact?.skype
        contactTwitterLabel.text = contact?.twitter
        contactNotesLabel.text = contact?.notes
        
        // Request image [nicer use AFNetworking imageView.setImageWithURLRequest(request ...]
        if let image = contact?.imageURL, let imageUrl = URL(string: image) {
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async(execute: {
                let imageData = try? Data(contentsOf: imageUrl)
                if let data = imageData {
                    DispatchQueue.main.async(execute: {
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
    
    func setContactGroups(_ groups: [GroupRecord]) {
        self.groups = groups
        //self.tableView.reloadSections(NSIndexSet(), withRowAnimation: .Fade)
        self.tableView.reloadData()
    }
    func setContactDetails(_ details: [ContactDetailRecord]) {
        self.details = details
        //self.tableView.reloadSections(NSIndexSet(), withRowAnimation: .Fade)
        self.tableView.reloadData()
    }
    
    // MARK: ContactUpdateDelegate
    
    func setContact(_ contact:ContactRecord) {
        self.contact = contact
        updateContact()
    }

    func dataAccessError(_ error: NSError?) {
        if let error = error {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    // MARK: UITableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Addresses"
        case 1: return "Groups"
        default: return nil
        }
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return bIsEditMode ? details.count + 1 : details.count
        case 1: return bIsEditMode ? dataAccess.allGroups.count : groups.count
        default: return 0
        }
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if (indexPath as NSIndexPath).section == 0 {
            return cellForDetailAtIndex((indexPath as NSIndexPath).row)
        }
        else {
            return cellForGroupAtIndex((indexPath as NSIndexPath).row)
        }
    }
    fileprivate func cellForDetailAtIndex(_ iDetail:Int) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: kAddressCell)
        if (cell == nil) {
            cell = DetailTableViewCell(style: .default, reuseIdentifier: kAddressCell)
        }
        if let cell = cell as? DetailTableViewCell {
            if iDetail == details.count {
                // Edit mode, new Address
                cell.typeLabel.text = "NEW"
                cell.addressLabel.text = "(Add new Address)"
                cell.accessoryType = .disclosureIndicator
            }
            else {
            let detail = details[iDetail]
                cell.typeLabel.text = detail.type
                cell.addressLabel.text = detail.description
                cell.accessoryType = bIsEditMode ? .disclosureIndicator : .none
            }
        }
        
        return cell!
    }
    fileprivate func cellForGroupAtIndex(_ iGroup:Int) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: kGroupCell)
        if (cell == nil) {
            cell = UITableViewCell(style: .default, reuseIdentifier: kGroupCell)
        }
        if bIsEditMode {
            let groupName = dataAccess.allGroups[iGroup].name
            cell?.textLabel?.text = groupName
            let bIsForUser = userHasGroupName(groupName)
            cell?.accessoryType = bIsForUser ? .checkmark : .none
        }
        else {
            cell?.textLabel?.text = groups[iGroup].name
            cell?.accessoryType = .checkmark
        }
        return cell!
    }
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        var bCanEdit = false
        if (indexPath as NSIndexPath).section == 0 && bIsEditMode {
            bCanEdit = true
        }
        return bCanEdit
    }
    // MARK: UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard bIsEditMode else { return }
        
        if (indexPath as NSIndexPath).section == 0 {
            performSegue(withIdentifier: kEditAddressSegue, sender: self)
        }
        else {
            if let contact = contact {
                let selectedGroup = dataAccess.allGroups[(indexPath as NSIndexPath).row]
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
    fileprivate func userHasGroupName(_ groupName:String) -> Bool {
        let bHasGroup = groups.contains(where: { (g) -> Bool in g.name == groupName })
        return bHasGroup
    }
    
    // MARK: Segue
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == kEditAddressSegue {
            if let vc = segue.destination as? AddressEditViewController {
                if let contact = contact, let row = (tableView.indexPathForSelectedRow as NSIndexPath?)?.row {
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
            if let vc = segue.destination as? ContactEditViewController {
                if let contact = contact {
                    vc.contact = contact
                    vc.updatedContactDelegate = self
                }
            }
        }
    }
}




















