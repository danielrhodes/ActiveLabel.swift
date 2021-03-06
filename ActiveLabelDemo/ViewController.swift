//
//  ViewController.swift
//  ActiveLabelDemo
//
//  Created by Johannes Schickling on 9/4/15.
//  Copyright © 2015 Optonaut. All rights reserved.
//

import UIKit
import ActiveLabel

class ViewController: UIViewController, ActiveLabelDelegate {
    
    let label = ActiveLabel()

    override func viewDidLoad() {
        super.viewDidLoad()
      
        label.delegate = self
        label.customize { label in
            label.detectorTypes = [.URL, .Mention, .Hashtag]
            label.attributedText = NSAttributedString(string: "This is a post with #multiple #hashtags and a @userhandle. Links are also supported like this one: http://optonaut.co.")
            label.numberOfLines = 0
            label.URLAttributes = [
              NSForegroundColorAttributeName: UIColor(red: 85.0/255, green: 238.0/255, blue: 151.0/255, alpha: 1),
              NSUnderlineStyleAttributeName: NSNumber(integer: NSUnderlineStyle.StyleSingle.rawValue)
            ]
          
            label.URLSelectedAttributes = [
              NSForegroundColorAttributeName: UIColor.redColor(),
            ]
          
            label.hashtagAttributes = [
              NSForegroundColorAttributeName: UIColor(red: 85.0/255, green: 172.0/255, blue: 238.0/255, alpha: 1),
              NSUnderlineStyleAttributeName: NSNumber(integer: NSUnderlineStyle.StyleSingle.rawValue)
            ]
          
            label.hashtagSelectedAttributes = [
              NSForegroundColorAttributeName: UIColor.redColor(),
            ]
          
            label.mentionAttributes = [
              NSForegroundColorAttributeName: UIColor(red: 238.0/255, green: 85.0/255, blue: 96.0/255, alpha: 1),
              NSUnderlineStyleAttributeName: NSNumber(integer: NSUnderlineStyle.StyleSingle.rawValue)
            ]
          
            label.mentionSelectedAttributes = [
              NSForegroundColorAttributeName: UIColor.redColor(),
            ]
        }
      
        label.frame = CGRect(x: 20, y: 40, width: view.frame.width - 40, height: 300)
        view.addSubview(label)
        
        
        // Do any additional setup after loading the view, typically from a nib.
    }
  
    func didSelectText(label: ActiveLabel, text: String, ofType type: ActiveType) {
      self.alert("\(type)", message: text)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func alert(title: String, message: String) {
        let vc = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.Alert)
        vc.addAction(UIAlertAction(title: "Ok", style: .Cancel, handler: nil))
        presentViewController(vc, animated: true, completion: nil)
    }

}

