//
//  ViewController.swift
//  DreamFactoryEZ
//
//  Created by Eric Elfner on 2016-05-03.
//  Copyright © 2016 Eric Elfner. All rights reserved.
//

import UIKit

class ContactsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, ContactsDelegate {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    private let kCellID = "CellID"
    private let dataAccess = DataAccess.sharedInstance

    private var names = [String]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let leftMenuItem = UIBarButtonItem(barButtonSystemItem: .Organize, target: self, action: #selector(settingsSelected))
        self.navigationItem.setLeftBarButtonItem(leftMenuItem, animated: false);
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(activityChanged), name: kRESTServerActiveCountUpdated, object: nil)
    }
    
    override func viewDidAppear(animated: Bool) {
        if dataAccess.isSignedIn() {
            DataAccess.sharedInstance.getContacts(nil, resultDelegate: self)
        }
        else {
            performSegueWithIdentifier("SignInSegue", sender: self)
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    @objc func settingsSelected() {
        // Could go to a complete Settings View, but here we just show the SignIn
        performSegueWithIdentifier("SignInSegue", sender: self)
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

    // MARK: ContactsDelegate
    func setContacts(contacts: [String]) {
        self.names = contacts
        self.tableView.reloadData()
    }
    func dataAccessError(error: NSError?) {
        if let error = error {
            print("Error: \(error)")
        }
    }
    
    // MARK: UITableViewDataSource
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return names.count
    }
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCellWithIdentifier(kCellID)
        
        if (cell == nil) {
            cell = UITableViewCell(style: .Default, reuseIdentifier: kCellID)
        }
        cell!.textLabel?.text = names[indexPath.row]
        return cell!
    }
}