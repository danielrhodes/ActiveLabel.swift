//
//  ActiveType.swift
//  ActiveLabel
//
//  Created by Johannes Schickling on 9/4/15.
//  Copyright © 2015 Optonaut. All rights reserved.
//

import Foundation

internal enum ActiveElement {
    case Mention(String)
    case Hashtag(String)
    case URL(String)
    case None
}

public enum ActiveType {
    case Mention
    case Hashtag
    case URL
    case None
}

func activelabel_clamp<T: Comparable>(value: T, lower: T, upper: T) -> T {
  return min(max(value, lower), upper)
}

typealias ActiveFilterPredicate = (String -> Bool)

struct ActiveBuilder {
    
    static func createMentionElements(fromText text: String, range: NSRange, filterPredicate: ActiveFilterPredicate?) -> [(range: NSRange, element: ActiveElement)] {
        let mentions = RegexParser.getMentions(fromText: text, range: range)
        let nsstring = text as NSString
        var elements: [(range: NSRange, element: ActiveElement)] = []
        
        for mention in mentions where mention.range.length > 2 {
            let range = NSRange(location: mention.range.location, length: mention.range.length)
            var word = nsstring.substringWithRange(range)
            if word.hasPrefix("@") {
                word.removeAtIndex(word.startIndex)
            }
          
            if filterPredicate?(word) ?? true {
                let element = ActiveElement.Mention(word)
                elements.append((range, element))
            }
        }
        return elements
    }
    
    static func createHashtagElements(fromText text: String, range: NSRange, filterPredicate: ActiveFilterPredicate?) -> [(range: NSRange, element: ActiveElement)] {
        let hashtags = RegexParser.getHashtags(fromText: text, range: range)
        let nsstring = text as NSString
        var elements: [(range: NSRange, element: ActiveElement)] = []
        
        for hashtag in hashtags where hashtag.range.length > 2 {
            let range = NSRange(location: hashtag.range.location, length: hashtag.range.length)
            var word = nsstring.substringWithRange(range)
            if word.hasPrefix("#") {
                word.removeAtIndex(word.startIndex)
            }
          
            if filterPredicate?(word) ?? true {
                let element = ActiveElement.Hashtag(word)
                elements.append((range, element))
            }
        }
        return elements
    }
    
    static func createURLElements(fromText text: String, range: NSRange) -> [(range: NSRange, element: ActiveElement)] {
        let urls = RegexParser.getURLs(fromText: text, range: range)
        let nsstring = text as NSString
        var elements: [(range: NSRange, element: ActiveElement)] = []
        
        for url in urls where url.range.length > 2 {
            let element = ActiveElement.URL(nsstring.substringWithRange(url.range))
            elements.append((url.range, element))
        }
      
        return elements
    }
}
