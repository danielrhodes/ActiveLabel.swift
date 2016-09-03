//
//  ActiveLabel.swift
//  ActiveLabel
//
//  Created by Johannes Schickling on 9/4/15.
//  Copyright © 2015 Optonaut. All rights reserved.
//

import Foundation
import UIKit

public protocol ActiveLabelDelegate: class {
  func didSelectText(_ label: ActiveLabel, text: String, ofType type: ActiveType)
}

extension Dictionary {
  fileprivate mutating func activelabel_merge<K, V>(_ dict: [K: V]){
    for (k, v) in dict {
      self.updateValue(v as! Value, forKey: k as! Key)
    }
  }

  fileprivate mutating func activelabel_removeKeys<K, V>(_ dict: [K: V]) {
    for (k, _) in dict {
      self.removeValue(forKey: k as! Key)
    }
  }
}

open class ActiveLabel: UILabel {

    // MARK: - public properties
    open weak var delegate: ActiveLabelDelegate?

    open var detectorTypes: [ActiveType]? {
      didSet {
        updateTextStorage(true)
      }
    }

    open var URLSelectedAttributes: [String: AnyObject] = [:]
    open var URLAttributes: [String: AnyObject] = [:] {
      didSet { updateTextStorage(false) }
    }

    open var mentionSelectedAttributes: [String: AnyObject] = [:]
    open var mentionAttributes: [String: AnyObject] = [:] {
      didSet { updateTextStorage(false) }
    }

    open var hashtagSelectedAttributes: [String: AnyObject] = [:]
    open var hashtagAttributes: [String: AnyObject] = [:] {
      didSet { updateTextStorage(false) }
    }

    open var lineSpacing: Float = 0 {
        didSet { updateTextStorage(false) }
    }

    fileprivate func shouldHandleType(_ type: ActiveType) -> Bool {
      if let detectors = detectorTypes {
        return detectors.contains(type)
      }

      return true
    }

    open func filterMention(_ predicate: ((String) -> Bool)) {
        mentionFilterPredicate = predicate
        updateTextStorage()
    }

    open func filterHashtag(_ predicate: ((String) -> Bool)) {
        hashtagFilterPredicate = predicate
        updateTextStorage()
    }

    // MARK: - override UILabel properties
    override open var text: String? {
        didSet { updateTextStorage() }
    }

    override open var attributedText: NSAttributedString? {
        didSet { updateTextStorage() }
    }

    override open var font: UIFont! {
        didSet { updateTextStorage(false) }
    }

    override open var textColor: UIColor! {
        didSet { updateTextStorage(false) }
    }

    override open var textAlignment: NSTextAlignment {
        didSet { updateTextStorage(false)}
    }

    override open var numberOfLines: Int {
        didSet { textContainer.maximumNumberOfLines = numberOfLines }
    }

    override open var lineBreakMode: NSLineBreakMode {
        didSet { textContainer.lineBreakMode = lineBreakMode }
    }

    override open var canBecomeFirstResponder: Bool {
      return true
    }


    // MARK: - init functions
    override public init(frame: CGRect) {
        super.init(frame: frame)
        _customizing = false
        setupLabel()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        _customizing = false
        setupLabel()
    }

    open override func awakeFromNib() {
        super.awakeFromNib()
        updateTextStorage()
    }

    open override func drawText(in rect: CGRect) {
        let range = NSRange(location: 0, length: textStorage.length)

        textContainer.size = rect.size
        let newOrigin = textOrigin(inRect: rect)

        layoutManager.drawBackground(forGlyphRange: range, at: newOrigin)
        layoutManager.drawGlyphs(forGlyphRange: range, at: newOrigin)
    }


    // MARK: - customzation
    open func customize(_ block: (_ label: ActiveLabel) -> ()) -> ActiveLabel{
        _customizing = true
        block(self)
        _customizing = false
        updateTextStorage()
        return self
    }

    // MARK: - Auto layout
    open override var intrinsicContentSize: CGSize {
        let superSize = super.intrinsicContentSize
        textContainer.size = CGSize(width: max(superSize.width, self.preferredMaxLayoutWidth), height: CGFloat.greatestFiniteMagnitude)
        let size = layoutManager.usedRect(for: textContainer)
        return CGSize(width: ceil(size.width), height: ceil(size.height))
    }

    // MARK: - touch events
    func onTouch(_ touch: UITouch) -> Bool {
        let location = touch.location(in: self)
        var avoidSuperCall = false

        switch touch.phase {
        case .began, .moved:
            if let element = element(at: location) {
                if element.range.location != selectedElement?.range.location || element.range.length != selectedElement?.range.length {
                    updateAttributesWhenSelected(false)
                    selectedElement = element
                    updateAttributesWhenSelected(true)
                }
                avoidSuperCall = true
            } else {
                updateAttributesWhenSelected(false)
                selectedElement = nil
            }
        case .ended:
            guard let selectedElement = selectedElement else { return avoidSuperCall }

            switch selectedElement.element {
              case .mention(let text) where shouldHandleType(.mention): didTap(text, type: .mention)
              case .hashtag(let text) where shouldHandleType(.hashtag): didTap(text, type: .hashtag)
              case .url(let text)     where shouldHandleType(.url):     didTap(text, type: .url)
              default: break
            }

            let when = DispatchTime.now() + Double(Int64(0.25 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
            DispatchQueue.main.asyncAfter(deadline: when) {
                self.updateAttributesWhenSelected(false)
                self.selectedElement = nil
            }
            avoidSuperCall = true
        case .cancelled:
            updateAttributesWhenSelected(false)
            selectedElement = nil
        case .stationary:
            break
        }

        return avoidSuperCall
    }

    // MARK: - private properties
    fileprivate var _customizing: Bool = true
    fileprivate var mentionFilterPredicate: ((String) -> Bool)?
    fileprivate var hashtagFilterPredicate: ((String) -> Bool)?

    fileprivate var selectedElement: (range: NSRange, element: ActiveElement)?
    fileprivate var heightCorrection: CGFloat = 0
    fileprivate lazy var textStorage = NSTextStorage()
    fileprivate lazy var layoutManager = NSLayoutManager()
    fileprivate lazy var textContainer = NSTextContainer()
    internal lazy var activeElements: [ActiveType: [(range: NSRange, element: ActiveElement)]] = [
        .mention: [],
        .hashtag: [],
        .url: [],
    ]

    // MARK: - helper functions
    fileprivate func setupLabel() {
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = lineBreakMode
        textContainer.maximumNumberOfLines = numberOfLines
        isUserInteractionEnabled = true
        addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(ActiveLabel.showMenu(_:))))
    }

    fileprivate func updateTextStorage(_ parseText: Bool = true) {
        if _customizing { return }
        // clean up previous active elements
        guard let attributedText = attributedText , attributedText.length > 0 else {
            clearActiveElements()
            textStorage.setAttributedString(NSAttributedString())
            setNeedsDisplay()
            return
        }

        let mutAttrString = addLineBreak(to: attributedText)

        if parseText {
            clearActiveElements()
            parseTextAndExtractActiveElements(from: mutAttrString)
        }

        self.addLinkAttribute(mutAttrString)
        self.textStorage.setAttributedString(mutAttrString)
        self.setNeedsDisplay()
    }

    fileprivate func clearActiveElements() {
        selectedElement = nil
        for (type, _) in activeElements {
            activeElements[type]?.removeAll()
        }
    }

    fileprivate func textOrigin(inRect rect: CGRect) -> CGPoint {
        let usedRect = layoutManager.usedRect(for: textContainer)
        heightCorrection = (rect.height - usedRect.height)/2
        let glyphOriginY = heightCorrection > 0 ? rect.origin.y + heightCorrection : rect.origin.y
        return CGPoint(x: rect.origin.x, y: glyphOriginY)
    }

    /// add link attribute
    fileprivate func addLinkAttribute(_ mutAttrString: NSMutableAttributedString) {
        var range = NSRange(location: 0, length: 0)
        let attributes = mutAttrString.attributes(at: 0, effectiveRange: &range)

        for (type, elements) in activeElements {
            var typeAttributes: [String: AnyObject] = [:]
            typeAttributes.activelabel_merge(attributes)

          switch type {
              case .mention where shouldHandleType(.mention): typeAttributes.activelabel_merge(mentionAttributes)
              case .hashtag where shouldHandleType(.hashtag): typeAttributes.activelabel_merge(hashtagAttributes)
              case .url     where shouldHandleType(.url):     typeAttributes.activelabel_merge(URLAttributes)
              default: break
            }

            for element in elements {
                mutAttrString.setAttributes(attributes, range: element.range)
            }
        }
    }

    /// use regex check all link ranges
    fileprivate func parseTextAndExtractActiveElements(from attrString: NSAttributedString) {
        let textString = attrString.string
        let textLength = textString.utf16.count
        let textRange = NSRange(location: 0, length: textLength)

        if shouldHandleType(.url) {
          let urlElements = ActiveBuilder.createURLElements(fromText: textString, range: textRange)
          activeElements[.url]?.append(contentsOf: urlElements)
          // Handle NSLinkAttributeName
          attrString.enumerateAttribute(NSLinkAttributeName, in: textRange, options: []) { (url, range, stop) in
            if let url: NSURL = url as? NSURL, let string = url.absoluteString {
              self.activeElements[.url]?.append((range: range, ActiveElement.url(string)))
            }
          }
        }

        //HASHTAGS
        if shouldHandleType(.hashtag) {
          let hashtagElements = ActiveBuilder.createHashtagElements(fromText: textString, range: textRange, filterPredicate: hashtagFilterPredicate)
          activeElements[.hashtag]?.append(contentsOf: hashtagElements)
        }

        //MENTIONS
        if shouldHandleType(.mention) {
          let mentionElements = ActiveBuilder.createMentionElements(fromText: textString, range: textRange, filterPredicate: mentionFilterPredicate)
          activeElements[.mention]?.append(contentsOf: mentionElements)
        }
    }


    /// add line break mode
    fileprivate func addLineBreak(to attrString: NSAttributedString) -> NSMutableAttributedString {
        let mutAttrString = NSMutableAttributedString(attributedString: attrString)

        var range = NSRange(location: 0, length: 0)
        var attributes = mutAttrString.attributes(at: 0, effectiveRange: &range)

        let paragraphStyle = attributes[NSParagraphStyleAttributeName] as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = NSLineBreakMode.byWordWrapping
        paragraphStyle.alignment = textAlignment
        paragraphStyle.lineSpacing = CGFloat(lineSpacing)

        attributes[NSParagraphStyleAttributeName] = paragraphStyle
        mutAttrString.setAttributes(attributes, range: range)

        return mutAttrString
    }

    fileprivate func updateAttributesWhenSelected(_ isSelected: Bool) {
        guard let selectedElement = selectedElement else { return }

        var range = NSRange(location: selectedElement.range.location, length: selectedElement.range.length)
        var attributes = textStorage.attributes(at: 0, effectiveRange: &range)
        if isSelected {
            switch selectedElement.element {
            case .mention(_) where shouldHandleType(.mention): attributes.activelabel_merge(mentionSelectedAttributes)
            case .hashtag(_) where shouldHandleType(.hashtag): attributes.activelabel_merge(hashtagSelectedAttributes)
            case .url(_)  where shouldHandleType(.url): attributes.activelabel_merge(URLSelectedAttributes)
            default: break
            }
        } else {
            switch selectedElement.element {
            case .mention(_) where shouldHandleType(.mention):
              attributes.activelabel_removeKeys(mentionSelectedAttributes)
              attributes.activelabel_merge(mentionAttributes)
            case .hashtag(_) where shouldHandleType(.hashtag):
              attributes.activelabel_removeKeys(hashtagSelectedAttributes)
              attributes.activelabel_merge(hashtagAttributes)
            case .url(_)     where shouldHandleType(.url):
              attributes.activelabel_removeKeys(URLSelectedAttributes)
              attributes.activelabel_merge(URLAttributes)
            default: break
            }
        }

        textStorage.addAttributes(attributes, range: selectedElement.range)

        setNeedsDisplay()
    }

    fileprivate func element(at location: CGPoint) -> (range: NSRange, element: ActiveElement)? {
        guard textStorage.length > 0 else {
            return nil
        }

        var correctLocation = location
        correctLocation.y -= heightCorrection
        let boundingRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: 0, length: textStorage.length), in: textContainer)

        guard boundingRect.contains(correctLocation) else {
            return nil
        }

        let index = layoutManager.glyphIndex(for: correctLocation, in: textContainer)
        for element in activeElements.map({ $0.1 }).joined() {
            if index >= element.range.location && index <= element.range.location + element.range.length {
                return element
            }
        }

        return nil
    }


    //MARK: - Handle UI Responder touches
    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        if onTouch(touch) { return }
        super.touchesBegan(touches, with: event)
    }

    open override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        if onTouch(touch) { return }
        super.touchesMoved(touches, with: event)
    }

    open override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        onTouch(touch)
        super.touchesCancelled(touches, with: event)
    }

    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        if onTouch(touch) { return }
        super.touchesEnded(touches, with: event)
    }

    //MARK: - ActiveLabel handler
    fileprivate func didTap(_ text: String, type: ActiveType) {
      delegate?.didSelectText(self, text: text, ofType: type)
    }
}

extension ActiveLabel {
  func showMenu(_ sender: AnyObject?) {
    becomeFirstResponder()
    let menu = UIMenuController.shared
    if !menu.isMenuVisible {
      menu.setTargetRect(bounds, in: self)
      menu.setMenuVisible(true, animated: true)
    }
  }

  override open func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
    if action == #selector(UIResponderStandardEditActions.copy(_:)) {
      return true
    }
    return false
  }


//  open func copy(_ sender: AnyObject?) {
//    let board = UIPasteboard.general
//    board.string = self.attributedText!.string
//    let menu = UIMenuController.shared
//    menu.setMenuVisible(false, animated: true)
//  }
}

extension ActiveLabel: UIGestureRecognizerDelegate {

    open func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    open func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    open func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
