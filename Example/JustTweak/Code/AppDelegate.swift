//
//  AppDelegate.swift
//  Copyright (c) 2016 Just Eat Holding Ltd. All rights reserved.
//

import JustTweak
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    let tweakAccessor = GeneratedTweakAccessor()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        let navigationController = window?.rootViewController as! UINavigationController
        let viewController = navigationController.topViewController as! ViewController
        viewController.tweakAccessor = tweakAccessor
        viewController.tweakManager = TweakAccessor.tweakManager
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        if tweakAccessor.shouldShowAlert {
            let alertController = UIAlertController(title: "Hello",
                                                    message: "Welcome to this Demo app!",
                                                    preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "Continue", style: .default, handler: nil))
            window?.rootViewController?.present(alertController, animated: true, completion: nil)
        }
    }
}
