//
//  AppDelegate.swift
//  JsonLDProcessor
//
//  Created by Vishnusankar on 17/03/18.
//  Copyright © 2018 global. All rights reserved.
//

import UIKit
import SwiftyJSON

//let CONTEXT : String = "@context"


//struct Document {
//
//    func expands(response:JSON) -> [JSON] {
//        var rootArray : [JSON] = [JSON]()
//
//        for key in (response.dictionary?.keys)! {
//
//            var currentNode = JSON()
//            let contextKey = keywords.description(keywordType: .CONTEXT)
//            let expandedKey = key.expandKey(activeContext: response["\(contextKey)"])
//
//        }
//        return rootArray
//    }
//}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        let path = Bundle.main.path(forResource: "jsonld", ofType: "txt")
        
        
        //read
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path!), options: .mappedIfSafe)
            let jsonResult : JSON = JSON(data)
            var rootNodeArray : [Dictionary<String,Any>] = [Dictionary<String,Any>]()
            var rootNodeDict : Dictionary<String,Any>? = Dictionary<String,Any>()
            
            let rootNode = Node.jsonLdToNodeStructure(json: jsonResult, key: "Root", activeContext: jsonResult["@context"])
            if let contextNodeIndex = rootNode.childNodes.index(where: { $0.key == "@context"}) {
                let contextNode = rootNode.childNodes[contextNodeIndex]
                rootNodeDict = rootNode.expandNode(activeContext: contextNode)
                
            }
            
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: rootNodeDict, options: .prettyPrinted)
                if let jsonString = String(data:jsonData, encoding:.utf8) {
                    print(jsonString)
                }
            } catch {
                print(error)
            }
        } catch {
            // handle error
            print("error")
        }
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

