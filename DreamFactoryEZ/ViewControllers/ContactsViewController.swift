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
    
    fileprivate let kCellID = "CellID"
    fileprivate let dataAccess = DataAccess.sharedInstance

    fileprivate var contacts = [ContactRecord]()
    fileprivate var contactsSectionsAlpha = [String]()
    fileprivate var contactsBySection = [String: [ContactRecord]]()
    fileprivate var contactsMatchingSearch = [ContactRecord]()

    fileprivate var currentGroup:GroupRecord? = nil
    fileprivate var newlyAddedContact:ContactRecord?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let leftMenuItem = UIBarButtonItem(barButtonSystemItem: .organize, target: self, action: #selector(settingsSelected))
        self.navigationItem.setLeftBarButton(leftMenuItem, animated: false);
        
        let rightMenuItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addSelected))
        self.navigationItem.setRightBarButton(rightMenuItem, animated: false);
        
        NotificationCenter.default.addObserver(self, selector: #selector(activityChanged), name: NSNotification.Name(rawValue: kRESTServerActiveCountUpdated), object: nil)

        if dataAccess.isSignedIn() {
            reloadContactsForGroup(currentGroup)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if !dataAccess.isSignedIn() {
            performSegue(withIdentifier: kSignInSegue, sender: self)
        }
        else if newlyAddedContact != nil {
            performSegue(withIdentifier: kViewNewContactSegue, sender: self)
        }
        else {
            tableView.reloadData()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @IBAction func refreshAction() {
        reloadContactsForGroup(currentGroup)
    }
    @IBAction func ezMoreAction() {
        // Link to GitHub
    }
    @objc func settingsSelected() {
        // Could go to a complete Settings View, but here we just show the SignIn
        performSegue(withIdentifier: kSignInSegue, sender: self)
    }
    
    @objc func addSelected() {
        performSegue(withIdentifier: kNewContactSegue, sender: self)
    }
    
    // Visual indication of activity. Could also use UIApplication.sharedApplication().networkActivityIndicatorVisible.
    @objc func activityChanged(_ notification:Notification) {
        let activityCount = ((notification as NSNotification).userInfo?["count"] as? NSNumber)?.intValue ?? 0
        if activityCount > 0 {
            activityIndicator.startAnimating()
        }
        else {
            activityIndicator.stopAnimating()
        }
    }

    fileprivate func reloadContactsForGroup(_ group:GroupRecord?) {
        currentGroup = group
        let label = group?.name ?? "ALL Groups"
        groupButton.setTitle(label, for: UIControlState())
        dataAccess.getContacts(currentGroup, resultDelegate: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        searchBar.resignFirstResponder()
        
        if segue.identifier == kSignInSegue {
            if let vc = segue.destination as? SignInViewController {
                vc.completionClosure = { ()->Void in
                    self.reloadContactsForGroup(self.currentGroup)
                }
            }
        }
        else if segue.identifier == kGroupsSegue {
            if let vc = segue.destination as? GroupsViewController {
                vc.selectedGroup = currentGroup
                vc.completionClosure = { (newGroup) in
                    self.reloadContactsForGroup(newGroup)
                }
            }
        }
        else if segue.identifier == kDetailSegue {
            if let vc = segue.destination as? ContactViewController {
                if let ip = tableView?.indexPathForSelectedRow {
                    if let contact = contactForIndexPath(ip) {
                        vc.contact = contact
                    }
                }
            }
        }
        else if segue.identifier == kNewContactSegue {
            if let vc = segue.destination as? ContactEditViewController {
                let contact = ContactRecord()
                vc.contact = contact
                vc.updatedContactDelegate = self
            }
        }
        else if segue.identifier == kViewNewContactSegue {
            if let vc = segue.destination as? ContactViewController {
                if let contact = newlyAddedContact {
                    vc.contact = contact
                    newlyAddedContact = nil
                }
            }
        }
    }
    
    // MARK: - ContactsDelegate
    
    func setContacts(_ contacts: [ContactRecord]) {
        self.contacts = contacts
        contactsSectionsAlpha = [String]()
        contactsBySection = [String: [ContactRecord]]()

        for contact in contacts {
            let name = contact.fullName
            let firstChar = String(name.prefix(1))
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
        tableView.setContentOffset(CGPoint.zero, animated: true)
        tableView.reloadData()
        search()
    }
    
    // MARK: - ContactUpdateDelegate
    
    func setContact(_ contact: ContactRecord) {
        newlyAddedContact = contact
    }
    
    func dataAccessError(_ error: NSError?) {
        if let error = error {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - UISearchBarDelegate
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        search()
    }
    fileprivate func isSearching() -> Bool {
        let searchText = searchBar.text ?? ""
        return !searchText.isEmpty
    }
    fileprivate func search() {
        let searchText = searchBar.text ?? ""
    
        if isSearching() {
            let searchString = searchText.uppercased()
            contactsMatchingSearch.removeAll()
            
            for contact in contacts {
                if contact.fullName.uppercased().contains(searchString) {
                    contactsMatchingSearch.append(contact)
                }
            }
        }
        tableView.reloadData()
    }
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    // MARK: - UITableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if isSearching() {
            return 1
        }
        return contactsSectionsAlpha.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
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
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: kCellID)
        
        if (cell == nil) {
            cell = UITableViewCell(style: .default, reuseIdentifier: kCellID)
        }
        var contactName = "(no-name)"
        if let contact = contactForIndexPath(indexPath) {
            contactName = contact.fullName
        }
        cell!.textLabel?.text = contactName
        return cell!
    }
    
    fileprivate func contactForIndexPath(_ indexPath:IndexPath) -> ContactRecord? {
        var contact:ContactRecord? = nil
        if isSearching() {
            contact = contactsMatchingSearch[(indexPath as NSIndexPath).row]
        }
        else {
            let sectionAlpha = contactsSectionsAlpha[(indexPath as NSIndexPath).section]
            if let sectionContacts = contactsBySection[sectionAlpha] {
                contact = sectionContacts[(indexPath as NSIndexPath).row]
            }
        }
        return contact
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if isSearching() {
            return nil
        }
        else {
            return contactsSectionsAlpha[section]
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        view.tintColor = UIColor(red: 210/255.0, green: 225/255.0, blue: 239/255.0, alpha: 1.0)
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
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











