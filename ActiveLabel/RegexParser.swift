//
//  RegexParser.swift
//  ActiveLabel
//
//  Created by Pol Quintana on 06/01/16.
//  Copyright © 2016 Optonaut. All rights reserved.
//

import Foundation
import UIKit

struct RegexParser {
    static let urlPattern = "(?:[^|[\\s.:;?\\-\\]<\\(]])?"
      + "((https?://|www\\.|pic\\.)[-\\w;/?:@&=+$\\|\\_.!~*\\|'()\\[\\]%#,☺]+[\\w/#](\\(\\))?)"

    static let hashtagRegex = try? NSRegularExpression(pattern: "(?:[^|\\s|$|[^.]])?(#[\\p{L}0-9_]*)", options: [.caseInsensitive])
    static let mentionRegex = try? NSRegularExpression(pattern: "(?:[^|\\s|$|.])?(@[\\p{L}0-9_]*)", options: [.caseInsensitive]);
    static let urlDetector = try? NSRegularExpression(pattern: urlPattern, options: [.caseInsensitive])

    static func getMentions(fromText text: String, range: NSRange) -> [NSTextCheckingResult] {
        guard let mentionRegex = mentionRegex else { return [] }
        return mentionRegex.matches(in: text, options: [], range: range)
    }

    static func getHashtags(fromText text: String, range: NSRange) -> [NSTextCheckingResult] {
        guard let hashtagRegex = hashtagRegex else { return [] }
        return hashtagRegex.matches(in: text, options: [], range: range)
    }

    static func getURLs(fromText text: String, range: NSRange) -> [NSTextCheckingResult] {
        guard let urlDetector = urlDetector else { return [] }
        return urlDetector.matches(in: text, options: [], range: range)
    }
}
