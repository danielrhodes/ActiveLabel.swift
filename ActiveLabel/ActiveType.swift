//
//  ActiveType.swift
//  ActiveLabel
//
//  Created by Johannes Schickling on 9/4/15.
//  Copyright © 2015 Optonaut. All rights reserved.
//

import Foundation

enum ActiveElement {
    case mention(String)
    case hashtag(String)
    case url(String)
    case none
}

public enum ActiveType {
    case mention
    case hashtag
    case url
    case none
}

func activelabel_clamp<T: Comparable>(_ value: T, lower: T, upper: T) -> T {
  return min(max(value, lower), upper)
}

typealias ActiveFilterPredicate = ((String) -> Bool)

struct ActiveBuilder {

    static func createMentionElements(fromText text: String, range: NSRange, filterPredicate: ActiveFilterPredicate?) -> [(range: NSRange, element: ActiveElement)] {
        let mentions = RegexParser.getMentions(fromText: text, range: range)
        let nsstring = text as NSString
        var elements: [(range: NSRange, element: ActiveElement)] = []

        for mention in mentions where mention.range.length > 2 {
            let range = NSRange(location: mention.range.location, length: mention.range.length)
            var word = nsstring.substring(with: range)
            if word.hasPrefix("@") {
                word.remove(at: word.startIndex)
            }

            if filterPredicate?(word) ?? true {
                let element = ActiveElement.mention(word)
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
            var word = nsstring.substring(with: range)
            if word.hasPrefix("#") {
                word.remove(at: word.startIndex)
            }

            if filterPredicate?(word) ?? true {
                let element = ActiveElement.hashtag(word)
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
            let element = ActiveElement.url(nsstring.substring(with: url.range))
            elements.append((url.range, element))
        }
        return elements
    }
}
