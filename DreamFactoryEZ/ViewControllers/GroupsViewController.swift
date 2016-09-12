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
    fileprivate let kCellID = "CellID"
    fileprivate let dataAccess = DataAccess.sharedInstance

    var selectedGroup:GroupRecord?
    var completionClosure: ((GroupRecord?)->Void)? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        NotificationCenter.default.addObserver(self, selector: #selector(activityChanged), name: NSNotification.Name(rawValue: kRESTServerActiveCountUpdated), object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if dataAccess.allGroups.count == 0 {
            // Could give some visual indication
            _ = navigationController?.popToRootViewController(animated: true)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
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

    @IBAction func groupsAction() {
        performSegue(withIdentifier: "GroupsSegue", sender: self)
    }
    
    // MARK: UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataAccess.allGroups.count + 1
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: kCellID)
        if (cell == nil) {
            cell = UITableViewCell(style: .default, reuseIdentifier: kCellID)
        }
        
        var cellLabel = "All Groups"
        var bIsCurrent = false
        if (indexPath as NSIndexPath).row > 0 {
            let cellGroup = dataAccess.allGroups[(indexPath as NSIndexPath).row - 1]
            cellLabel = cellGroup.name
            bIsCurrent = (cellGroup.id == selectedGroup?.id)
        }
        else {
            bIsCurrent = (selectedGroup == nil)
        }
        cell!.textLabel?.text = cellLabel

        cell!.accessoryType = bIsCurrent ? .checkmark : .none
        cell!.selectionStyle = .none
        
        return cell!
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if (indexPath as NSIndexPath).row == 0 {
            selectedGroup = nil
        }
        else {
            let group = dataAccess.allGroups[(indexPath as NSIndexPath).row - 1]
            selectedGroup = group
        }
        // Set select and exit
        completionClosure?(selectedGroup)
        _ = navigationController?.popViewController(animated: true)
    }
}




















