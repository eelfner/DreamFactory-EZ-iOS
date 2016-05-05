//
//  SignInViewController.swift
//  DreamFactoryEZ
//
//  Created by Eric Elfner on 2016-05-04.
//  Copyright © 2016 Eric Elfner. All rights reserved.
//

import UIKit

class SignInViewController: UIViewController, SignInDelegate {

    private var bFirstShowingOfView:Bool = true
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func viewDidAppear(animated: Bool) {
        if bFirstShowingOfView && DataAccess.sharedInstance.isSignedIn() {
            performSegueWithIdentifier("ContactsSegue", sender: self)
        }
    }

    @IBAction func signInAction() {
        DataAccess.sharedInstance.signInWithEmail("user1@zcage.com", password: "password", signInDelegate: self)
    }
    
    // MARK: - SignInDelegate
    func userIsSignedIn(bSignedIn: Bool) {
        if bSignedIn {
            self.bFirstShowingOfView = false
            self.performSegueWithIdentifier("ContactsSegue", sender: self)
        }
        else {
            
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
