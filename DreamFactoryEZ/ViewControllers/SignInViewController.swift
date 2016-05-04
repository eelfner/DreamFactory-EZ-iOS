//
//  SignInViewController.swift
//  DreamFactoryEZ
//
//  Created by Eric Elfner on 2016-05-04.
//  Copyright © 2016 Eric Elfner. All rights reserved.
//

import UIKit

class SignInViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func viewDidAppear(animated: Bool) {
        if API.sharedInstance.isSignedIn {
            performSegueWithIdentifier("ContactsSegue", sender: self)
        }
    }

    @IBAction func signInAction() {
        API.sharedInstance.signInWithEmail("user1@zcage.com", password: "password") { (result) in
            if result.bIsSuccess {
                print("SignIn Success")
            }
            else {
                print("SignIn Error: \(result.error)")
            }
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