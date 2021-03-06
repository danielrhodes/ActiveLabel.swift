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
  func didSelectText(label: ActiveLabel, text: String, ofType type: ActiveType)
}

extension Dictionary {
  private mutating func activelabel_merge<K, V>(dict: [K: V]){
    for (k, v) in dict {
      self.updateValue(v as! Value, forKey: k as! Key)
    }
  }
  
  private mutating func activelabel_removeKeys<K, V>(dict: [K: V]) {
    for (k, _) in dict {
      self.removeValueForKey(k as! Key)
    }
  }
}

@IBDesignable public class ActiveLabel: UILabel {
    
    // MARK: - public properties
    public weak var delegate: ActiveLabelDelegate?
  
    public var detectorTypes: [ActiveType]? {
      didSet {
        updateTextStorage(parseText: true)
      }
    }
  
    @IBInspectable public var URLSelectedAttributes: [String: AnyObject] = [:]
    @IBInspectable public var URLAttributes: [String: AnyObject] = [:] {
      didSet { updateTextStorage(parseText: false) }
    }
  
    @IBInspectable public var mentionSelectedAttributes: [String: AnyObject] = [:]
    @IBInspectable public var mentionAttributes: [String: AnyObject] = [:] {
      didSet { updateTextStorage(parseText: false) }
    }
  
    @IBInspectable public var hashtagSelectedAttributes: [String: AnyObject] = [:]
    @IBInspectable public var hashtagAttributes: [String: AnyObject] = [:] {
      didSet { updateTextStorage(parseText: false) }
    }
  
    @IBInspectable public var lineSpacing: Float = 0 {
        didSet { updateTextStorage(parseText: false) }
    }
  
    private func shouldHandleType(type: ActiveType) -> Bool {
      if let detectors = detectorTypes {
        return detectors.contains(type)
      }
      
      return true
    }

    public func filterMention(predicate: (String) -> Bool) {
        mentionFilterPredicate = predicate
        updateTextStorage()
    }

    public func filterHashtag(predicate: (String) -> Bool) {
        hashtagFilterPredicate = predicate
        updateTextStorage()
    }
    
    override public var attributedText: NSAttributedString? {
        didSet { updateTextStorage() }
    }

    public override var numberOfLines: Int {
        didSet { textContainer.maximumNumberOfLines = numberOfLines }
    }
    
    public override var lineBreakMode: NSLineBreakMode {
        didSet { textContainer.lineBreakMode = lineBreakMode }
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

    public override func awakeFromNib() {
        super.awakeFromNib()
        updateTextStorage()
    }
    
    public override func drawTextInRect(rect: CGRect) {
        let range = NSRange(location: 0, length: textStorage.length)
        
        textContainer.size = rect.size
        let newOrigin = textOrigin(inRect: rect)
        
        layoutManager.drawBackgroundForGlyphRange(range, atPoint: newOrigin)
        layoutManager.drawGlyphsForGlyphRange(range, atPoint: newOrigin)
    }
    
    // MARK: - customzation
    public func customize(block: (label: ActiveLabel) -> ()) -> ActiveLabel{
        _customizing = true
        block(label: self)
        _customizing = false
        updateTextStorage()
        return self
    }

    // MARK: - Auto layout
    public override func intrinsicContentSize() -> CGSize {
        let superSize = super.intrinsicContentSize()
        textContainer.size = CGSize(width: max(superSize.width, self.preferredMaxLayoutWidth), height: CGFloat.max)
        let size = layoutManager.usedRectForTextContainer(textContainer)
        return CGSize(width: ceil(size.width), height: ceil(size.height))
    }
    
    // MARK: - touch events
    func onTouch(touch: UITouch) -> Bool {
        let location = touch.locationInView(self)
        var avoidSuperCall = false
        
        switch touch.phase {
        case .Began, .Moved:
            if let element = elementAtLocation(location) {
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
        case .Ended:
            guard let selectedElement = selectedElement else { return avoidSuperCall }
            
            switch selectedElement.element {
            case .Mention(let text) where shouldHandleType(.Mention): didTap(text, type: .Mention)
            case .Hashtag(let text) where shouldHandleType(.Hashtag): didTap(text, type: .Hashtag)
            case .URL(let text)     where shouldHandleType(.URL):     didTap(text, type: .URL)
            default: break
            }
            
            let when = dispatch_time(DISPATCH_TIME_NOW, Int64(0.25 * Double(NSEC_PER_SEC)))
            dispatch_after(when, dispatch_get_main_queue()) {
                self.updateAttributesWhenSelected(false)
                self.selectedElement = nil
            }
            avoidSuperCall = true
        case .Cancelled:
            updateAttributesWhenSelected(false)
            selectedElement = nil
        case .Stationary:
            break
        }
      
        return avoidSuperCall
    }
    
    // MARK: - private properties
    private var _customizing: Bool = true

    private var mentionFilterPredicate: ((String) -> Bool)?
    private var hashtagFilterPredicate: ((String) -> Bool)?

    private var selectedElement: (range: NSRange, element: ActiveElement)?
    private var heightCorrection: CGFloat = 0
    private lazy var textStorage = NSTextStorage()
    private lazy var layoutManager = NSLayoutManager()
    private lazy var textContainer = NSTextContainer()
    internal lazy var activeElements: [ActiveType: [(range: NSRange, element: ActiveElement)]] = [
        .Mention: [],
        .Hashtag: [],
        .URL: [],
    ]
    
    // MARK: - helper functions
    private func setupLabel() {
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = lineBreakMode
        textContainer.maximumNumberOfLines = numberOfLines
        userInteractionEnabled = true
        addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(ActiveLabel.showMenu(_:))))
    }
    
    private func updateTextStorage(parseText parseText: Bool = true) {
        if _customizing { return }
        // clean up previous active elements
        guard let attributedText = attributedText where attributedText.length > 0 else {
            clearActiveElements()
            textStorage.setAttributedString(NSAttributedString())
            setNeedsDisplay()
            return
        }
        
        let mutAttrString = addLineBreak(attributedText)

        if parseText {
            clearActiveElements()
            parseTextAndExtractActiveElements(mutAttrString)
        }
        
        self.addLinkAttribute(mutAttrString)
        self.textStorage.setAttributedString(mutAttrString)
        self.invalidateIntrinsicContentSize()
        self.setNeedsDisplay()
    }

    private func clearActiveElements() {
        selectedElement = nil
        for (type, _) in activeElements {
            activeElements[type]?.removeAll()
        }
    }

    private func textOrigin(inRect rect: CGRect) -> CGPoint {
        let usedRect = layoutManager.usedRectForTextContainer(textContainer)
        heightCorrection = (rect.height - usedRect.height)/2
        let glyphOriginY = heightCorrection > 0 ? rect.origin.y + heightCorrection : rect.origin.y
        return CGPoint(x: rect.origin.x, y: glyphOriginY)
    }
    
    /// add link attribute
    private func addLinkAttribute(mutAttrString: NSMutableAttributedString) {
        var range = NSRange(location: 0, length: 0)
        let attributes = mutAttrString.attributesAtIndex(0, effectiveRange: &range)
      
        for (type, elements) in activeElements {
            var typeAttributes: [String: AnyObject] = [:]
            typeAttributes.activelabel_merge(attributes)
          
            switch type {
            case .Mention where shouldHandleType(.Mention): typeAttributes.activelabel_merge(mentionAttributes)
            case .Hashtag where shouldHandleType(.Hashtag): typeAttributes.activelabel_merge(hashtagAttributes)
            case .URL     where shouldHandleType(.URL):     typeAttributes.activelabel_merge(URLAttributes)
            default: break
            }
            
            for element in elements {
              mutAttrString.setAttributes(typeAttributes, range: element.range)
            }
        }
    }
    
    /// use regex check all link ranges
    private func parseTextAndExtractActiveElements(attrString: NSAttributedString) {
        let textString = attrString.string
        let textLength = textString.utf16.count
      
        if textLength == 0 {
          return
        }
      
        let textRange = NSRange(location: 0, length: textLength)

        //URLS
        if shouldHandleType(.URL) {
          let urlElements = ActiveBuilder.createURLElements(fromText: textString, range: textRange)
          activeElements[.URL]?.appendContentsOf(urlElements)
          // Handle NSLinkAttributeName
          attrString.enumerateAttribute(NSLinkAttributeName, inRange: textRange, options: []) { (url, range, stop) in
            if let url = url, let string = url.absoluteString {
              self.activeElements[.URL]?.append((range: range, ActiveElement.URL(string)))
            }
          }
        }
      
        //HASHTAGS
        if shouldHandleType(.Hashtag) {
          let hashtagElements = ActiveBuilder.createHashtagElements(fromText: textString, range: textRange, filterPredicate: hashtagFilterPredicate)
          activeElements[.Hashtag]?.appendContentsOf(hashtagElements)
        }
      
        //MENTIONS
        if shouldHandleType(.Mention) {
          let mentionElements = ActiveBuilder.createMentionElements(fromText: textString, range: textRange, filterPredicate: mentionFilterPredicate)
          activeElements[.Mention]?.appendContentsOf(mentionElements)
        }
    }

    
    /// add line break mode
    private func addLineBreak(attrString: NSAttributedString) -> NSMutableAttributedString {
        let mutAttrString = NSMutableAttributedString(attributedString: attrString)
        
        var range = NSRange(location: 0, length: 0)
        var attributes = mutAttrString.attributesAtIndex(0, effectiveRange: &range)
        
        let paragraphStyle = attributes[NSParagraphStyleAttributeName] as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = NSLineBreakMode.ByWordWrapping
        paragraphStyle.alignment = textAlignment
        paragraphStyle.lineSpacing = CGFloat(lineSpacing)
        
        attributes[NSParagraphStyleAttributeName] = paragraphStyle
        mutAttrString.setAttributes(attributes, range: range)
        
        return mutAttrString
    }
    
    private func updateAttributesWhenSelected(isSelected: Bool) {
        guard let selectedElement = selectedElement else { return }
      
        var range = NSRange(location: selectedElement.range.location, length: selectedElement.range.length)
        var attributes = textStorage.attributesAtIndex(0, effectiveRange: &range)
        if isSelected {
            switch selectedElement.element {
            case .Mention(_) where shouldHandleType(.Mention): attributes.activelabel_merge(mentionSelectedAttributes)
            case .Hashtag(_) where shouldHandleType(.Hashtag): attributes.activelabel_merge(hashtagSelectedAttributes)
            case .URL(_)  where shouldHandleType(.URL): attributes.activelabel_merge(URLSelectedAttributes)
            default: break
            }
        } else {
            switch selectedElement.element {
            case .Mention(_) where shouldHandleType(.Mention):
              attributes.activelabel_removeKeys(mentionSelectedAttributes)
              attributes.activelabel_merge(mentionAttributes)
            case .Hashtag(_) where shouldHandleType(.Hashtag):
              attributes.activelabel_removeKeys(hashtagSelectedAttributes)
              attributes.activelabel_merge(hashtagAttributes)
            case .URL(_)     where shouldHandleType(.URL):
              attributes.activelabel_removeKeys(URLSelectedAttributes)
              attributes.activelabel_merge(URLAttributes)
            default: break
            }
        }
        
        textStorage.addAttributes(attributes, range: selectedElement.range)
        
        setNeedsDisplay()
    }
    
    private func elementAtLocation(location: CGPoint) -> (range: NSRange, element: ActiveElement)? {
        guard textStorage.length > 0 else { return nil }

        var correctLocation = location
        correctLocation.y -= heightCorrection
        let boundingRect = layoutManager.boundingRectForGlyphRange(NSRange(location: 0, length: textStorage.length), inTextContainer: textContainer)
      
        guard boundingRect.contains(correctLocation) else {
            return nil
        }
        
        let index = layoutManager.glyphIndexForPoint(correctLocation, inTextContainer: textContainer)
      
        for element in activeElements.map({ $0.1 }).flatten() {
            if index >= element.range.location && index <= element.range.location + element.range.length {
                return element
            }
        }
        
        return nil
    }
  
    //MARK: - Handle UI Responder touches
    public override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        guard let touch = touches.first else { return }
        if onTouch(touch) { return }
        super.touchesBegan(touches, withEvent: event)
    }

    public override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        guard let touch = touches.first else { return }
        if onTouch(touch) { return }
        super.touchesMoved(touches, withEvent: event)
    }
    
    public override func touchesCancelled(touches: Set<UITouch>?, withEvent event: UIEvent?) {
        guard let touch = touches?.first else { return }
        onTouch(touch)
        super.touchesCancelled(touches, withEvent: event)
    }
    
    public override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        guard let touch = touches.first else { return }
        if onTouch(touch) { return }
        super.touchesEnded(touches, withEvent: event)
    }
    
    //MARK: - ActiveLabel handler
    private func didTap(text: String, type: ActiveType) {
      delegate?.didSelectText(self, text: text, ofType: type)
    }
}

extension ActiveLabel {
  func showMenu(sender: AnyObject?) {
    becomeFirstResponder()
    let menu = UIMenuController.sharedMenuController()
    if !menu.menuVisible {
      menu.setTargetRect(bounds, inView: self)
      menu.setMenuVisible(true, animated: true)
    }
  }
  
  override public func canPerformAction(action: Selector, withSender sender: AnyObject?) -> Bool {
    if action == "copy:" {
      return true
    }
    return false
  }
  
  override public func copy(sender: AnyObject?) {
    let board = UIPasteboard.generalPasteboard()
    board.string = self.attributedText!.string
    let menu = UIMenuController.sharedMenuController()
    menu.setMenuVisible(false, animated: true)
  }
  
  override public func canBecomeFirstResponder() -> Bool {
    return true
  }
}

extension ActiveLabel: UIGestureRecognizerDelegate {
    
    public func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    public func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOfGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    public func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailByGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
