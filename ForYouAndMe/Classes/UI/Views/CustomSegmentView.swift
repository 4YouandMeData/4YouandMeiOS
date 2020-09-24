//
//  CustomSegmentView.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 23/09/2020.
//

import UIKit

///It's a custom switch properties Model structure
struct CustomSegmentViewProperties {
    var backgroundColor: UIColor = ColorPalette.color(withType: .secondary)
    var sliderColor: [UIColor] = [ColorPalette.color(withType: .primary)]
    var sliderInsideTextColor: UIColor = ColorPalette.color(withType: .primaryText)
    var sliderOutsideTextColor: UIColor = ColorPalette.color(withType: .secondaryText)
    var font: UIFont = FontPalette.fontStyleData(forStyle: .header3).font
    var cornerRadius: CGFloat = 0
    var sliderOffset: CGFloat = 0
    var switchTexts: [StudyPeriod]
    
    init(switchTexts: [StudyPeriod]) {
        self.switchTexts = switchTexts
    }
}

///This Protocol is used to delegate back to owner of this view before and after moving to a particular index.
protocol CustomSegmentViewDelegate: class {
    func segmentWillChange(_ studyPeriod: StudyPeriod)
    func segmentDidChanged(_ studyPeriod: StudyPeriod)
}

extension CustomSegmentViewDelegate {
    func segmentWillChange(_ studyPeriod: StudyPeriod) {
        
    }
    func segmentDidChanged(_ studyPeriod: StudyPeriod) {
        
    }
}

///This is custom UIControl class designed for custom animated switch control with multiple siwtches.
@IBDesignable class CustomSegmentView: UIControl {
    // MARK: - ALL PRIVATE PROPERTIES -
    fileprivate var backgroundView: UIView = UIView()
    fileprivate var sliderView: GradientView = GradientView(type: .primaryBackground)
    fileprivate var properties: CustomSegmentViewProperties!
    fileprivate var innerLabels: [UILabel] = []
    fileprivate var outerLabels: [UILabel] = []
    
    // MARK: - ALL PUBLIC PROPERTIES -
    var selectedIndex: Int = 0
    
    weak var switchDelegate: CustomSegmentViewDelegate?
    @IBInspectable var switchTitles: String? // Need to pass Comma seperated titles.
    
    var switchProperties: CustomSegmentViewProperties?
    
    // MARK: - CUSTOM INITIALIZERS AND HANDLER METHODS -
    
    init(frame: CGRect, switchProperties: CustomSegmentViewProperties) {
        super.init(frame: frame)
        properties = switchProperties
        properties.cornerRadius = 0
        setupCustomSwitchUI()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setUpTheSwitchUI()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUpTheSwitchUI() {
        properties = switchProperties
        setupCustomSwitchUI()
    }
    
    ///This will create the based UI needed for Custom switch based on proerties model.
    fileprivate func setupCustomSwitchUI() {
        //remove old UI if it has
        for innerLabel in innerLabels {
            innerLabel.removeFromSuperview()
        }
        innerLabels.removeAll()
        
        for outerLabel in outerLabels {
            outerLabel.removeFromSuperview()
        }
        outerLabels.removeAll()
        backgroundView.removeFromSuperview()
        sliderView.removeFromSuperview()
        
        backgroundView.backgroundColor = properties.backgroundColor
        backgroundColor = properties.backgroundColor
        addSubview(backgroundView)
        
        for index in 0..<properties.switchTexts.count {
            let studyPeriod = properties.switchTexts[index]
            let innerLabel: UILabel = createLabel(studyPeriod.title,
                                                  textColor: switchProperties?.sliderInsideTextColor ?? properties.sliderInsideTextColor)
            innerLabel.tag = index
            innerLabel.accessibilityIdentifier = "Custom_Switch_\(studyPeriod.title)_InnerLabel_\(index)Id"
            backgroundView.addSubview(innerLabel)
            innerLabels.append(innerLabel)
            
            let tapGesture: UITapGestureRecognizer = UITapGestureRecognizer(target: self,
                                                                            action: #selector(CustomSegmentView.handleTouchGesture(_:)))
            innerLabel.accessibilityTraits = UIAccessibilityTraits.button
            innerLabel.addGestureRecognizer(tapGesture)
            innerLabel.isUserInteractionEnabled = true
        }
        
//        sliderView.leftGradientColor = properties.sliderColor.first
//        sliderView.rightGradientColor = properties.sliderColor.last
        addSubview(sliderView)
        
        for index in 0..<properties.switchTexts.count {
            let studyPeriod = properties.switchTexts[index]
            let outerLabel: UILabel = createLabel(studyPeriod.title, textColor: properties.sliderOutsideTextColor)
            outerLabel.tag = index
            outerLabel.accessibilityIdentifier = "Custom_Switch_\(studyPeriod.title)_OuterLabel_\(index)Id"
            outerLabel.accessibilityTraits = UIAccessibilityTraits.button
            sliderView.addSubview(outerLabel)
            outerLabels.append(outerLabel)
        }
        
//        let panGesture: UIPanGestureRecognizer = UIPanGestureRecognizer(target: self,
//                                                                        action: #selector(CustomSegmentView.handlePanGesture(_:)))
//        sliderView.addGestureRecognizer(panGesture)
        changeTheLayoutAttributes()
    }
    
    fileprivate func createLabel(_ text: String, textColor: UIColor) -> UILabel {
        let sliderTextlabel: UILabel = UILabel()
        sliderTextlabel.text = text
        sliderTextlabel.font = properties.font
        sliderTextlabel.adjustsFontSizeToFitWidth = true
        sliderTextlabel.textAlignment = .center
        sliderTextlabel.textColor = textColor
        return sliderTextlabel
    }
    
    /// In Layout subviews based on everytime superview frame changes, we ae changing inner and outer label frames accordingly.
    override func layoutSubviews() {
        changeTheLayoutAttributes()
    }
    
    func changeTheLayoutAttributes() {
        properties.cornerRadius = 0
        backgroundView.layer.cornerRadius = frame.size.height / 2
        layer.cornerRadius = frame.size.height / 2
        backgroundView.backgroundColor = properties.backgroundColor
//        sliderView.leftGradientColor = properties.sliderColor.first
//        sliderView.rightGradientColor = properties.sliderColor.last
        
        backgroundView.frame = convert(frame, from: superview)
        if properties.switchTexts.isEmpty == false {
            let sliderWidth: CGFloat = frame.size.width / CGFloat(properties.switchTexts.count)
            let sliderOffset = properties.sliderOffset
            sliderView.frame = CGRect(x: CGFloat(sliderWidth * CGFloat(selectedIndex)) + sliderOffset,
                                      y: backgroundView.frame.origin.y + sliderOffset,
                                      width: CGFloat(sliderWidth),
                                      height: backgroundView.frame.height)
            
            ///the title labels were not centre virtically, hence added offcet of -2 to y axis
            let yOffset: CGFloat = -2
            for index in 0..<innerLabels.count {
                let label = innerLabels[index]
                label.frame = CGRect(x: index * Int(sliderWidth) + 1,
                                     y: Int(yOffset),
                                     width: Int(sliderWidth) - 1,
                                     height: Int(backgroundView.frame.height + 2))
                label.font = properties.font
                label.backgroundColor = .white
                label.textColor = properties.sliderInsideTextColor
            }
            
            for index in 0..<outerLabels.count {
                let label = outerLabels[index]
                let xPos = sliderView.convert(CGPoint(x: index * Int(sliderWidth), y: 0), from: backgroundView).x
                label.frame = CGRect(x: xPos, y: -properties.sliderOffset + yOffset,
                                     width: CGFloat(sliderWidth - 1),
                                     height: backgroundView.frame.height + 2)
                label.font = properties.font
                label.textColor = properties.sliderOutsideTextColor
            }
        }
        
        sliderView.clipsToBounds = true
        backgroundView.clipsToBounds = true
        clipsToBounds = true
    }
    
    // MARK: - GESTURE HANDLING METHODS -
    
    /// This gesture useful to move to particualar index by tapping on it.
    @objc internal func handleTouchGesture(_ tapGesture: UITapGestureRecognizer) {
        if let gestureView = tapGesture.view { selectedIndex = gestureView.tag }
        moveToIndex(selectedIndex, animated: true)
    }
    
    /// This gesture useful to move to particualar index by panning to it.
    @objc internal func handlePanGesture(_ panGesture: UIPanGestureRecognizer) {
        if panGesture.state == .changed {
            handlePanGestureOnChangeState(panGesture: panGesture)
            
        } else if panGesture.state == .cancelled || panGesture.state == .ended || panGesture.state == .failed {
            handlePanGestureOnCancelEndFailState(panGesture: panGesture)
        }
    }
    
    /// This gesture useful to move to particualar index by panning to it.
    /// - parameter panGesture: UIPanGestureRecognizer
    fileprivate func handlePanGestureOnChangeState(panGesture: UIPanGestureRecognizer) {
        let oldFrame = sliderView.frame
        let minPos = properties.sliderOffset
        let maxPos = frame.width - properties.sliderOffset - sliderView.frame.width
        var center = panGesture.view?.center ?? CGPoint.zero
        let translation = panGesture.translation(in: panGesture.view)
        
        center = CGPoint(x: center.x + translation.x, y: center.y)
        panGesture.view?.center = center
        panGesture.setTranslation(CGPoint.zero, in: panGesture.view)
        
        if sliderView.frame.origin.x < minPos {
            sliderView.frame.origin.x = minPos
        } else if sliderView.frame.origin.x > maxPos {
            sliderView.frame.origin.x = maxPos
        }
        
        let newFrame = sliderView.frame
        let offRect = CGRect(x: newFrame.origin.x - oldFrame.origin.x, y: newFrame.origin.y - oldFrame.origin.y, width: 0, height: 0)
        
        for label in outerLabels {
            label.frame.origin = CGPoint(x: label.frame.origin.x - offRect.origin.x, y: label.frame.origin.y - offRect.origin.y)
        }
    }
    
    /// This gesture useful to move to particualar index by panning to it.
    /// - parameter panGesture: UIPanGestureRecognizer
    fileprivate func handlePanGestureOnCancelEndFailState(panGesture: UIPanGestureRecognizer) {
        var allSwitchDistances = [CGFloat]()
        
        for index in 0..<properties.switchTexts.count {
            let possibleX = CGFloat(index) * sliderView.frame.width
            let distance = possibleX - sliderView.frame.origin.x
            allSwitchDistances.append(abs(distance))
        }
        
        let index = allSwitchDistances.firstIndex(of: allSwitchDistances.min() ?? 0) ?? 0
        switchDelegate?.segmentWillChange(StudyPeriod.allCases[index])
        
        let sliderWidth = frame.width / CGFloat(properties.switchTexts.count)
        let desiredX = sliderWidth * CGFloat(index) + properties.sliderOffset
        
        if sliderView.frame.origin.x != desiredX {
            let evenOlderFrame = sliderView.frame
            let distance = desiredX - sliderView.frame.origin.x
            let time = abs(distance / 300)
            
            UIView.animate(withDuration: Double(time), animations: { [weak self] in
                self?.sliderView.frame.origin.x = desiredX
                let newFrame = self?.sliderView.frame
                let offRect = CGRect(x: (newFrame?.origin.x ?? 0) - evenOlderFrame.origin.x,
                                     y: (newFrame?.origin.y ?? 0) - evenOlderFrame.origin.y,
                                     width: 0,
                                     height: 0)
                
                for label in self?.outerLabels ?? [] {
                    label.frame.origin = CGPoint(x: label.frame.origin.x - offRect.origin.x,
                                                 y: label.frame.origin.y - offRect.origin.y)
                }
                
            }, completion: { [weak self] _ in
                self?.selectedIndex = index
                self?.switchDelegate?.segmentDidChanged(StudyPeriod.allCases[index])
            })
        } else {
            selectedIndex = index
            switchDelegate?.segmentDidChanged(StudyPeriod.allCases[index])
        }
    }
    
    // MARK: - SETTER METHODS -
    
    /// This method can call to select the particular index programmatically.
    /// - parameter index: Switch index which needs to be selected.
    /// - parameter animated: Pass thorugh to animate the presentation otherwise pass false.
    func selectIndex(_ index: Int = 0, animated: Bool = true) {
        guard index < properties.switchTexts.count else { return }
        
        moveToIndex(index, animated: animated, shouldDelegate: false)
        selectedIndex = index
    }
    
    /// This method is used to move to the particular index programmatically.
    /// - parameter index: Switch index which needs to be selected.
    /// - parameter animated: Pass thorugh to animate the presentation otherwise pass false.
    fileprivate func moveToIndex(_ index: Int, animated: Bool = true, shouldDelegate: Bool = true) {
        switchDelegate?.segmentWillChange(StudyPeriod.allCases[index])
        let sliderWidth: Int = (Int(frame.size.width) / properties.switchTexts.count) + 1
        let oldFrame = sliderView.frame
        let sliderOffset = properties.sliderOffset
        let newFrame = CGRect(x: CGFloat((sliderWidth * index)) + sliderOffset,
                              y: backgroundView.frame.origin.y + sliderOffset,
                              width: CGFloat(sliderWidth) - (2 * sliderOffset),
                              height: frame.height - (2 * sliderOffset))
        let offRect = CGRect(x: newFrame.origin.x - oldFrame.origin.x, y: newFrame.origin.y - oldFrame.origin.y, width: 0, height: 0)
        let duration = animated == true ? 0.25: 0
        
        UIView.animate(withDuration: duration, delay: 0.0, options: .curveEaseIn, animations: { [weak self] in
            self?.sliderView.frame = newFrame
            if let outerLabels = self?.outerLabels {
                for label in outerLabels {
                    label.frame = CGRect(x: label.frame.origin.x - offRect.origin.x,
                                         y: label.frame.origin.y - offRect.origin.y,
                                         width: label.frame.width,
                                         height: label.frame.height)
                }
            }
            }, completion: { [weak self] _ in
                if shouldDelegate == true {
                    self?.switchDelegate?.segmentDidChanged(StudyPeriod.allCases[index])
                }
        })
    }
}
