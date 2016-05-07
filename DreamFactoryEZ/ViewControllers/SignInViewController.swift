//
//  SignInViewController.swift
//  DreamFactoryEZ
//
//  Created by Eric Elfner on 2016-05-04.
//  Copyright © 2016 Eric Elfner. All rights reserved.
//

import UIKit

class SignInViewController: UIViewController, SignInDelegate, RegistrationDelegate {

    @IBOutlet weak var signInView: UIView!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var registerButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    private let dataAccess = DataAccess.sharedInstance
    var completionClosure: (()->Void)? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        signInView.layer.cornerRadius = 6
        signInView.layer.masksToBounds = true
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(activityChanged), name: kRESTServerActiveCountUpdated, object: nil)
    }

    override func viewWillAppear(animated: Bool) {
        updateViewForSignedInState(dataAccess.isSignedIn())
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    // Could just use UIApplication network, but it is not dramatic enough
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

    @IBAction func registrationAction() {
        let alert = UIAlertController(title: "Registration", message: "Who are you?", preferredStyle: .Alert)
        alert.addTextFieldWithConfigurationHandler { (textField) in
            textField.placeholder = "Email"
            textField.keyboardType = .EmailAddress
        }
        alert.addTextFieldWithConfigurationHandler { (textField) in
            textField.placeholder = "Password"
            textField.secureTextEntry = true
        }
        let regAction = UIAlertAction(title: "Register", style: .Default) { (_) in
            let email = (alert.textFields![0] as UITextField).text ?? ""
            let pwd = (alert.textFields![1] as UITextField).text ?? ""
            
            self.registerEmail(email, pwd: pwd)
        }
        alert.addAction(regAction)
        alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        presentViewController(alert, animated: true, completion: nil)
        
    }
    func registerEmail(email:String, pwd:String) {
        dataAccess.registerWithEmail(email, password: pwd, registrationDelegate: self)
    }
    // MARK: - RegisterDelegate
    func userIsRegisteredSuccess(bSuccess:Bool, message: String?) {
        if bSuccess {
            self.navigationController?.popViewControllerAnimated(true)
        }
        else {
            let serverMsg = message ?? "Please try again."
            let msg = "Invalid credentials. Please try again. \n[\(serverMsg)]"
            let alert = UIAlertController(title: "Registration Failed", message: msg, preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default, handler: nil))
            presentViewController(alert, animated: true, completion: nil)
            updateViewForSignedInState(false)
        }
    }
    @IBAction func signInAction() {
        if dataAccess.isSignedIn() {
            dataAccess.signOut(self)
        }
        else {
            let email = emailTextField.text ?? ""  // "user1@zcage.com"
            let pwd = passwordTextField.text ?? "" // "password"
            dataAccess.signInWithEmail(email, password: pwd, signInDelegate: self)
        }
    }
    
    
    // MARK: - SignInDelegate
    func userIsSignedInSuccess(bSignedIn: Bool, message: String?) {
        if bSignedIn {
            self.completionClosure?()
            self.navigationController?.popViewControllerAnimated(true)
        }
        else {
            let msg = message ?? "Please retry."
            let alert = UIAlertController(title: "Sign In Failed", message: msg, preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default, handler: nil))
            presentViewController(alert, animated: true, completion: nil)
            updateViewForSignedInState(false)
        }
    }
    func userIsSignedOut() {
        updateViewForSignedInState(false)
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
