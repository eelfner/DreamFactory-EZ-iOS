//
//  SignInViewController.swift
//  DreamFactoryEZ
//
//  Created by Eric Elfner on 2016-05-04.
//  Copyright © 2016 Eric Elfner. All rights reserved.
//

import UIKit

class SignInViewController: UIViewController, SignInDelegate {

    @IBOutlet weak var signInView: UIView!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var registerButton: UIButton!
    
    
    private var bFirstShowingOfView:Bool = true
    private let dataAccess = DataAccess.sharedInstance
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        signInView.layer.cornerRadius = 6
        signInView.layer.masksToBounds = true
    }

    override func viewWillAppear(animated: Bool) {
        updateViewForSignedInState(dataAccess.isSignedIn())
    }
    override func viewDidAppear(animated: Bool) {
        if bFirstShowingOfView && dataAccess.isSignedIn() {
            performSegueWithIdentifier("ContactsSegue", sender: self)
        }
    }
    func updateViewForSignedInState(bIsSignedIn:Bool) {
        if bIsSignedIn {
            emailTextField.enabled = false
            emailTextField.backgroundColor = UIColor.grayColor()
            passwordTextField.enabled = false
            passwordTextField.backgroundColor = UIColor.grayColor()
            signInButton.setTitle("Sign Out", forState: .Normal)
            registerButton.hidden = true
        }
        else {
            emailTextField.enabled = true
            emailTextField.backgroundColor = UIColor.whiteColor()
            passwordTextField.enabled = true
            passwordTextField.backgroundColor = UIColor.whiteColor()
            signInButton.setTitle("Sign In", forState: .Normal)
            registerButton.hidden = false
        }
    }

    @IBAction func signInAction() {
        if dataAccess.isSignedIn() {
            dataAccess.signOut(self)
        }
        else {
            dataAccess.signInWithEmail("user1@zcage.com", password: "password", signInDelegate: self)
        }
    }
    
    // MARK: - SignInDelegate
    func userIsSignedIn(bSignedIn: Bool) {
        if bSignedIn {
            self.bFirstShowingOfView = false
            self.performSegueWithIdentifier("ContactsSegue", sender: self)
        }
        else {
            updateViewForSignedInState(false)
        }
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
