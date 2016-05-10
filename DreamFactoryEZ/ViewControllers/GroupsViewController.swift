//
//  ViewController.swift
//  DreamFactoryEZ
//
//  Created by Eric Elfner on 2016-05-03.
//  Copyright © 2016 Eric Elfner. All rights reserved.
//

import UIKit

class GroupsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    private let kCellID = "CellID"
    private let dataAccess = DataAccess.sharedInstance

    var selectedGroup:GroupRecord?
    var completionClosure: ((GroupRecord?)->Void)? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(activityChanged), name: kRESTServerActiveCountUpdated, object: nil)
    }
    
    override func viewDidAppear(animated: Bool) {
        if dataAccess.allGroups.count == 0 {
            // Could give some visual indication
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
    
    // MARK: UITableViewDataSource
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataAccess.allGroups.count + 1
    }
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCellWithIdentifier(kCellID)
        if (cell == nil) {
            cell = UITableViewCell(style: .Default, reuseIdentifier: kCellID)
        }
        
        var cellLabel = "All Groups"
        var bIsCurrent = false
        if indexPath.row > 0 {
            let cellGroup = dataAccess.allGroups[indexPath.row - 1]
            cellLabel = cellGroup.name
            bIsCurrent = (cellGroup.id == selectedGroup?.id)
        }
        else {
            bIsCurrent = (selectedGroup == nil)
        }
        cell!.textLabel?.text = cellLabel

        cell!.accessoryType = bIsCurrent ? .Checkmark : .None
        cell!.selectionStyle = .None
        
        return cell!
    }
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath.row == 0 {
            selectedGroup = nil
        }
        else {
            let group = dataAccess.allGroups[indexPath.row - 1]
            selectedGroup = group
        }
        // Set select and exit
        completionClosure?(selectedGroup)
        navigationController?.popViewControllerAnimated(true)
    }
}




















