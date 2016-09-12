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
    @IBOutlet weak var serverLabel: UILabel!
    
    fileprivate let dataAccess = DataAccess.sharedInstance
    var completionClosure: (()->Void)? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        signInView.layer.cornerRadius = 6
        signInView.layer.masksToBounds = true
        serverLabel.text = kBaseInstanceUrl
        NotificationCenter.default.addObserver(self, selector: #selector(activityChanged), name: NSNotification.Name(rawValue: kRESTServerActiveCountUpdated), object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        updateViewForSignedInState(dataAccess.isSignedIn())
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // Could just use UIApplication network, but it is not dramatic enough
    @objc func activityChanged(_ notification:Notification) {
        let activityCount = ((notification as NSNotification).userInfo?["count"] as? NSNumber)?.intValue ?? 0
        if activityCount > 0 {
            activityIndicator.startAnimating()
            //UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        }
        else {
            activityIndicator.stopAnimating()
            //UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        }
    }
    
    func updateViewForSignedInState(_ bIsSignedIn:Bool) {
        if bIsSignedIn {
            emailTextField.text = dataAccess.signedInUser()
            emailTextField.isEnabled = false
            emailTextField.backgroundColor = UIColor.gray
            passwordTextField.text = nil
            passwordTextField.isEnabled = false
            passwordTextField.backgroundColor = UIColor.gray
            signInButton.setTitle("Sign Out", for: UIControlState())
            registerButton.isHidden = true
        }
        else {
            emailTextField.text = "user1@zcage.com"
            emailTextField.isEnabled = true
            emailTextField.backgroundColor = UIColor.white
            passwordTextField.text = "password"
            passwordTextField.isEnabled = true
            passwordTextField.backgroundColor = UIColor.white
            signInButton.setTitle("Sign In", for: UIControlState())
            registerButton.isHidden = false
        }
    }

    @IBAction func registrationAction() {
        let alert = UIAlertController(title: "Registration", message: "Who are you?", preferredStyle: .alert)
        alert.addTextField { (textField) in
            textField.placeholder = "Email"
            textField.keyboardType = .emailAddress
        }
        alert.addTextField { (textField) in
            textField.placeholder = "Password"
            textField.isSecureTextEntry = true
        }
        let regAction = UIAlertAction(title: "Register", style: .default) { (_) in
            let email = (alert.textFields![0] as UITextField).text ?? ""
            let pwd = (alert.textFields![1] as UITextField).text ?? ""
            
            self.registerEmail(email, pwd: pwd)
        }
        alert.addAction(regAction)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
        
    }
    func registerEmail(_ email:String, pwd:String) {
        dataAccess.registerWithEmail(email, password: pwd, registrationDelegate: self)
    }
    
    // MARK: - RegisterDelegate
    
    func userIsRegisteredSuccess(_ bSuccess:Bool, message: String?) {
        if bSuccess {
            self.completionClosure?()
            _ = self.navigationController?.popViewController(animated: true)
        }
        else {
            let serverMsg = message ?? "Please try again."
            let msg = "Invalid credentials. Please try again. \n[\(serverMsg)]"
            let alert = UIAlertController(title: "Registration Failed", message: msg, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: nil))
            present(alert, animated: true, completion: nil)
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
    
    func userIsSignedInSuccess(_ bSignedIn: Bool, message: String?) {
        if bSignedIn {
            self.completionClosure?()
            _ = self.navigationController?.popViewController(animated: true)
        }
        else {
            let msg = message ?? "Please retry."
            let alert = UIAlertController(title: "Sign In Failed", message: msg, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: nil))
            present(alert, animated: true, completion: nil)
            updateViewForSignedInState(false)
        }
    }
    
    func userIsSignedOut() {
        updateViewForSignedInState(false)
    }
}
