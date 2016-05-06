//
//  ViewController.swift
//  DreamFactoryEZ
//
//  Created by Eric Elfner on 2016-05-03.
//  Copyright © 2016 Eric Elfner. All rights reserved.
//

import UIKit

protocol GroupDependent {
    func resetCurrentGroupTo(group:NSNumber?)
}

class ContactsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, ContactsDelegate {
    let kGroupsSegue = "GroupsSegue"
    let kSignInSegue = "SignInSegue"
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var groupButton: UIButton!
    
    private let kCellID = "CellID"
    private let dataAccess = DataAccess.sharedInstance

    private var contacts = [ContactRecord]()
    private var currentGroup:GroupRecord? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let leftMenuItem = UIBarButtonItem(barButtonSystemItem: .Organize, target: self, action: #selector(settingsSelected))
        self.navigationItem.setLeftBarButtonItem(leftMenuItem, animated: false);
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(activityChanged), name: kRESTServerActiveCountUpdated, object: nil)

        if dataAccess.isSignedIn() {
            reloadContactsForGroup(currentGroup)
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        if !dataAccess.isSignedIn() {
            performSegueWithIdentifier(kSignInSegue, sender: self)
        }
        else {
            tableView.reloadData()
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    @objc func settingsSelected() {
        // Could go to a complete Settings View, but here we just show the SignIn
        performSegueWithIdentifier(kSignInSegue, sender: self)
    }

    @objc func activityChanged(notification:NSNotification) {
        let activityCount = (notification.userInfo?["count"] as? NSNumber)?.longValue ?? 0
        if activityCount > 0 {
            activityIndicator.startAnimating()
            //UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        }
        else {
            activityIndicator.stopAnimating()
            //UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        }
    }

    private func reloadContactsForGroup(group:GroupRecord?) {
        currentGroup = group
        let label = group?.name ?? "ALL Groups"
        groupButton.setTitle(label, forState: .Normal)
        dataAccess.getContacts(currentGroup, resultDelegate: self)
    }
    
    @IBAction func groupsAction() {
        performSegueWithIdentifier(kGroupsSegue, sender: self)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == kSignInSegue {
            if let vc = segue.destinationViewController as? SignInViewController {
                vc.completionClosure = { _ in
                    self.reloadContactsForGroup(nil)
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
    }
    
    // MARK: ContactsDelegate
    func setContacts(contacts: [ContactRecord]) {
        self.contacts = contacts
        self.tableView.reloadData()
    }
    func dataAccessError(error: NSError?) {
        if let error = error {
            print("Error: \(error)")
        }
    }
    
    // MARK: UITableViewDataSource
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return contacts.count
    }
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCellWithIdentifier(kCellID)
        
        if (cell == nil) {
            cell = UITableViewCell(style: .Default, reuseIdentifier: kCellID)
        }
        let contact = contacts[indexPath.row]
        cell!.textLabel?.text = contact.fullName
        return cell!
    }
}