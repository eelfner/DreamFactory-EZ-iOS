//
//  ViewController.swift
//  DreamFactoryEZ
//
//  Created by Eric Elfner on 2016-05-03.
//  Copyright © 2016 Eric Elfner. All rights reserved.
//

import UIKit

class ContactsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, ContactsDelegate, ContactUpdateDelegate, UISearchBarDelegate {
    let kGroupsSegue = "GroupsSegue"
    let kSignInSegue = "SignInSegue"
    let kDetailSegue = "DetailSegue"
    let kNewContactSegue = "NewContactSegue"
    let kViewNewContactSegue = "ViewNewContactSegue"
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var groupButton: UIButton!
    @IBOutlet weak var searchBar: UISearchBar!
    
    private let kCellID = "CellID"
    private let dataAccess = DataAccess.sharedInstance

    private var contacts = [ContactRecord]()
    private var contactsSectionsAlpha = [String]()
    private var contactsBySection = [String: [ContactRecord]]()
    private var contactsMatchingSearch = [ContactRecord]()

    private var currentGroup:GroupRecord? = nil
    private var newlyAddedContact:ContactRecord?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let leftMenuItem = UIBarButtonItem(barButtonSystemItem: .Organize, target: self, action: #selector(settingsSelected))
        self.navigationItem.setLeftBarButtonItem(leftMenuItem, animated: false);
        
        let rightMenuItem = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: #selector(addSelected))
        self.navigationItem.setRightBarButtonItem(rightMenuItem, animated: false);
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(activityChanged), name: kRESTServerActiveCountUpdated, object: nil)

        if dataAccess.isSignedIn() {
            reloadContactsForGroup(currentGroup)
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        if !dataAccess.isSignedIn() {
            performSegueWithIdentifier(kSignInSegue, sender: self)
        }
        else if newlyAddedContact != nil {
            performSegueWithIdentifier(kViewNewContactSegue, sender: self)
        }
        else {
            tableView.reloadData()
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    @IBAction func refreshAction() {
        reloadContactsForGroup(currentGroup)
    }
    @IBAction func ezMoreAction() {
        // Link to GitHub
    }
    @objc func settingsSelected() {
        // Could go to a complete Settings View, but here we just show the SignIn
        performSegueWithIdentifier(kSignInSegue, sender: self)
    }
    
    @objc func addSelected() {
        performSegueWithIdentifier(kNewContactSegue, sender: self)
    }
    
    // Visual indication of activity. Could also use UIApplication.sharedApplication().networkActivityIndicatorVisible.
    @objc func activityChanged(notification:NSNotification) {
        let activityCount = (notification.userInfo?["count"] as? NSNumber)?.longValue ?? 0
        if activityCount > 0 {
            activityIndicator.startAnimating()
        }
        else {
            activityIndicator.stopAnimating()
        }
    }

    private func reloadContactsForGroup(group:GroupRecord?) {
        currentGroup = group
        let label = group?.name ?? "ALL Groups"
        groupButton.setTitle(label, forState: .Normal)
        dataAccess.getContacts(currentGroup, resultDelegate: self)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == kSignInSegue {
            if let vc = segue.destinationViewController as? SignInViewController {
                vc.completionClosure = { _ in
                    self.reloadContactsForGroup(self.currentGroup)
                }
            }
        }
        else if segue.identifier == kGroupsSegue {
            if let vc = segue.destinationViewController as? GroupsViewController {
                vc.selectedGroup = currentGroup
                vc.completionClosure = { (newGroup) in
                    self.reloadContactsForGroup(newGroup)
                }
            }
        }
        else if segue.identifier == kDetailSegue {
            if let vc = segue.destinationViewController as? ContactViewController {
                if let ip = tableView?.indexPathForSelectedRow {
                    if let contact = contactForIndexPath(ip) {
                        vc.contact = contact
                    }
                }
            }
        }
        else if segue.identifier == kNewContactSegue {
            if let vc = segue.destinationViewController as? ContactEditViewController {
                let contact = ContactRecord()
                vc.contact = contact
                vc.updatedContactDelegate = self
            }
        }
        else if segue.identifier == kViewNewContactSegue {
            if let vc = segue.destinationViewController as? ContactViewController {
                if let contact = newlyAddedContact {
                    vc.contact = contact
                    newlyAddedContact = nil
                }
            }
        }
    }
    
    // MARK: ContactsDelegate
    
    func setContacts(contacts: [ContactRecord]) {
        self.contacts = contacts
        contactsSectionsAlpha = [String]()
        contactsBySection = [String: [ContactRecord]]()

        for contact in contacts {
            let name = contact.fullName
            let firstChar = name.substringToIndex(name.startIndex.advancedBy(1, limit: name.endIndex))
            if contactsBySection.keys.contains(firstChar) {
                contactsBySection[firstChar]!.append(contact)
            }
            else {
                var alphaSection = [ContactRecord]()
                alphaSection.append(contact)
                contactsSectionsAlpha.append(firstChar)
                contactsBySection[firstChar] = alphaSection
            }
        }
        tableView.setContentOffset(CGPointZero, animated: true)
        tableView.reloadData()
        search()
    }
    
    // MARK: ContactUpdateDelegate
    
    func setContact(contact: ContactRecord) {
        newlyAddedContact = contact
    }
    
    func dataAccessError(error: NSError?) {
        if let error = error {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - UISearchBarDelegate
    
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        search()
    }
    private func isSearching() -> Bool {
        let searchText = searchBar.text ?? ""
        return !searchText.isEmpty
    }
    private func search() {
        let searchText = searchBar.text ?? ""
    
        if isSearching() {
            let searchString = searchText.uppercaseString
            contactsMatchingSearch.removeAll()
            
            for contact in contacts {
                if contact.fullName.uppercaseString.containsString(searchString) {
                    contactsMatchingSearch.append(contact)
                }
            }
        }
        tableView.reloadData()
    }

    // MARK: UITableViewDataSource
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        if isSearching() {
            return 1
        }
        return contactsSectionsAlpha.count
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var rowCount = 0
        if isSearching() {
             rowCount = contactsMatchingSearch.count
        }
        else {
            if let sectionContacts = contactsBySection[contactsSectionsAlpha[section]] {
                rowCount = sectionContacts.count
            }
        }
        return rowCount
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCellWithIdentifier(kCellID)
        
        if (cell == nil) {
            cell = UITableViewCell(style: .Default, reuseIdentifier: kCellID)
        }
        var contactName = "(no-name)"
        if let contact = contactForIndexPath(indexPath) {
            contactName = contact.fullName
        }
        cell!.textLabel?.text = contactName
        return cell!
    }
    
    private func contactForIndexPath(indexPath:NSIndexPath) -> ContactRecord? {
        var contact:ContactRecord? = nil
        if isSearching() {
            contact = contactsMatchingSearch[indexPath.row]
        }
        else {
            let sectionAlpha = contactsSectionsAlpha[indexPath.section]
            if let sectionContacts = contactsBySection[sectionAlpha] {
                contact = sectionContacts[indexPath.row]
            }
        }
        return contact
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if isSearching() {
            return nil
        }
        else {
            return contactsSectionsAlpha[section]
        }
    }
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    func tableView(tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        view.tintColor = UIColor(red: 210/255.0, green: 225/255.0, blue: 239/255.0, alpha: 1.0)
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
//        if editingStyle == .Delete {
//            if isSearch {
//                let record = displayContentArray[indexPath.row]
//                let index = record.lastName.substringToIndex(record.lastName.startIndex.advancedBy(1)).uppercaseString
//                var displayArray = contactSectionsDictionary[index]!
//                displayArray.removeObject(record)
//                if displayArray.count == 0 {
//                    // remove tile header if there are no more tiles in that group
//                    alphabetArray.removeObject(index)
//                }
//                contactSectionsDictionary[index] = displayArray
//                
//                // need to delete everything with references to contact before
//                // removing contact its self
//                removeContactWithContactId(record.id)
//                
//                displayContentArray.removeAtIndex(indexPath.row)
//                tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
//            } else {
//                let sectionLetter = alphabetArray[indexPath.section]
//                var sectionContacts = contactSectionsDictionary[sectionLetter]!
//                let record = sectionContacts[indexPath.row]
//                
//                sectionContacts.removeAtIndex(indexPath.row)
//                contactSectionsDictionary[sectionLetter] = sectionContacts
//                
//                tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
//                if sectionContacts.count == 0 {
//                    alphabetArray.removeAtIndex(indexPath.section)
//                }
//                
//                removeContactWithContactId(record.id)
//            }
//        }
    }
}











