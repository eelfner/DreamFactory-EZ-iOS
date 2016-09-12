//
//  AddressEditViewController.swift
//  DreamFactoryEZ
//
//  Created by Eric Elfner on 2016-05-10.
//  Copyright © 2016 Eric Elfner. All rights reserved.
//

import UIKit

class AddressEditViewController: UIViewController, ContactDetailUpdateDelegate, ContactDetailDeleteDelegate {

    fileprivate let dataAccess = DataAccess.sharedInstance
    var contact:ContactRecord? = nil
    var address:ContactDetailRecord? = nil
    var contactDetailDelegate:ContactDetailDelegate? = nil
    
    fileprivate let types = ["Work", "Home", "Mobile", "Other"]
    
    @IBOutlet weak var typeSegmentedControl: UISegmentedControl!
    @IBOutlet weak var phoneTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var addressTextField: UITextField!
    @IBOutlet weak var cityTextField: UITextField!
    @IBOutlet weak var stateTextField: UITextField!
    @IBOutlet weak var zipTextField: UITextField!
    @IBOutlet weak var countryTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        let rightMenuItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveSelected))
        self.navigationItem.setRightBarButton(rightMenuItem, animated: false);
    }

    override func viewWillAppear(_ animated: Bool) {
        if !dataAccess.isSignedIn() {
            _ = navigationController?.popToRootViewController(animated: true)
        }
        else if contact == nil || address == nil {
            _ = navigationController?.popViewController(animated: true)
        }
        else {
            setValuesFromModel()
        }
    }
    
    @objc fileprivate func saveSelected() {
        if let contact = contact {
            let addressRecord = ContactDetailRecord(contactId: contact.id)
            addressRecord.id = address?.id ?? -1
            addressRecord.address = addressTextField.text ?? ""
            addressRecord.city = cityTextField.text ?? ""
            addressRecord.country = countryTextField.text ?? ""
            addressRecord.email = emailTextField.text ?? ""
            addressRecord.phone = phoneTextField.text ?? ""
            addressRecord.state = stateTextField.text ?? ""
            addressRecord.zipCode = zipTextField.text ?? ""
            
            addressRecord.type = types[typeSegmentedControl.selectedSegmentIndex]
            
            dataAccess.addOrUpdateAddress(addressRecord, delegate: self)
        }
    }
    
    @IBAction func removeItemAction() {
        if let id = address?.id, let name = contact?.fullName {
            let alert = UIAlertController(title: "Remove Address", message: "Remove this address for \(name). Are you sure?", preferredStyle: .alert)
            let delAction = UIAlertAction(title: "Remove", style: .destructive) { (_) in
                self.dataAccess.removeAddressForId(id, delegate: self)
            }
            alert.addAction(delAction)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        }
    }
    fileprivate func setValuesFromModel() {
        if let address = address {
            typeSegmentedControl.selectedSegmentIndex = types.index(of: address.type.capitalized) ?? 0
            phoneTextField.text = address.phone
            emailTextField.text = address.email
            addressTextField.text = address.address
            cityTextField.text = address.city
            stateTextField.text = address.state
            zipTextField.text = address.zipCode
            countryTextField.text = address.country
        }
    }
    
    // MARK: ContactDetailUpdateDelegate, ContactDetailDeleteDelegate
    
    func dataAccessSuccess() {
        if let contactID = contact?.id, let cdd = contactDetailDelegate {
            dataAccess.getContactDetails(contactID, resultDelegate: cdd)
            _ = navigationController?.popViewController(animated: true)
        }
    }
    func dataAccessError(_ error:NSError?) {
        let serverMsg = error?.localizedDescription ?? "Validation Issue"
        let msg = "Server reported error. Please try again. \n[\(serverMsg)]"
        let alert = UIAlertController(title: "Save Issue", message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}
