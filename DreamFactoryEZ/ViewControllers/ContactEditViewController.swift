//
//  AddressEditViewController.swift
//  DreamFactoryEZ
//
//  Created by Eric Elfner on 2016-05-10.
//  Copyright © 2016 Eric Elfner. All rights reserved.
//

import UIKit

class ContactEditViewController: UIViewController, ContactUpdateDelegate {

    private let dataAccess = DataAccess.sharedInstance
    var contact:ContactRecord? = nil
    var updatedContactDelegate:ContactUpdateDelegate? = nil
    
    @IBOutlet weak var firstNameTextField: UITextField!
    @IBOutlet weak var lastNameTextField: UITextField!
    @IBOutlet weak var skypeTextField: UITextField!
    @IBOutlet weak var twitterTextField: UITextField!
    @IBOutlet weak var imageURLTextField: UITextField!
    @IBOutlet weak var notesTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        let rightMenuItem = UIBarButtonItem(barButtonSystemItem: .Save, target: self, action: #selector(saveSelected))
        self.navigationItem.setRightBarButtonItem(rightMenuItem, animated: false);
    }

    override func viewWillAppear(animated: Bool) {
        if !dataAccess.isSignedIn() || updatedContactDelegate == nil {
            navigationController?.popToRootViewControllerAnimated(true)
        }
        else {
            setValuesFromModel()
        }
    }
    
    @objc private func saveSelected() {
        if let contact = contact {
            let contactRecord = ContactRecord()
            contactRecord.id = contact.id
            contactRecord.firstName = firstNameTextField.text ?? ""
            contactRecord.lastName = lastNameTextField.text ?? ""
            contactRecord.skype = skypeTextField.text ?? ""
            contactRecord.twitter = twitterTextField.text ?? ""
            contactRecord.notes = imageURLTextField.text ?? ""
            
            dataAccess.addOrUpdateContact(contactRecord, delegate: self)
        }
    }
    
    @IBAction func removeItemAction() {
//        if let contact = contact {
//            let name = contact.fullName
//            let alert = UIAlertController(title: "Remove Contact", message: "Remove this contact: \(name). Are you sure?", preferredStyle: .Alert)
//            let delAction = UIAlertAction(title: "Remove", style: .Destructive) { (_) in
//                self.dataAccess.removeContactForId(contact.id, delegate: self)
//            }
//            alert.addAction(delAction)
//            alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
//            presentViewController(alert, animated: true, completion: nil)
//        }
    }
    private func setValuesFromModel() {
        if let contact = contact {
            firstNameTextField.text = contact.firstName
            lastNameTextField.text = contact.lastName
            skypeTextField.text = contact.skype
            twitterTextField.text = contact.twitter
            imageURLTextField.text = contact.notes
        }
    }
    
    // MARK: ContactUpdateDelegate
    
    // Pass the updated/new contact to the caller (ContactsVC, ContactVC) to handle.
    func setContact(contact:ContactRecord) {
        if contact.id == -1 { // New
            navigationController?.popViewControllerAnimated(false)
            
            
        }
        else if let ucd = updatedContactDelegate {
            ucd.setContact(contact)
            navigationController?.popViewControllerAnimated(true)
        }
    }
    func dataAccessError(error:NSError?) {
        let serverMsg = error?.localizedDescription ?? "Validation Issue"
        let msg = "Server reported error. Please try again. \n[\(serverMsg)]"
        let alert = UIAlertController(title: "Save Issue", message: msg, preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default, handler: nil))
        presentViewController(alert, animated: true, completion: nil)
    }
}
