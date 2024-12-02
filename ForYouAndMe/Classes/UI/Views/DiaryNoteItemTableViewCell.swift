//
//  DiaryNoteTableViewCell.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 02/12/24.
//

import UIKit

class DiaryNoteItemTableViewCell: UITableViewCell {
    
    private lazy var noteImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.autoSetDimensions(to: CGSize(width: 18, height: 18))
        return imageView
    }()
    
    private lazy var noteTitleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var noteDescriptionLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()
    
    private var buttonPressedCallback: NotificationCallback?
        
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.selectionStyle = .none
        self.backgroundColor = .clear
        
        let containerView = UIStackView()
        containerView.axis = .horizontal
        containerView.distribution = .fill
        
        containerView.addArrangedSubview(self.noteImageView, horizontalInset: 8.0)
        
        let textView = UIStackView()
        textView.axis = .vertical
        textView.distribution = .fill
        textView.addArrangedSubview(self.noteTitleLabel, horizontalInset: 16.0)
        textView.addBlankSpace(space: 8.0)
        textView.addArrangedSubview(self.noteDescriptionLabel, horizontalInset: 16.0)
        textView.addBlankSpace(space: 8.0)
        
        containerView.addArrangedSubview(textView)
        
        containerView.addImage(withImage: ImagePalette.templateImage(withName: .arrowRight) ?? UIImage(),
                           color: ColorPalette.color(withType: .primaryText),
                           sizeDimension: 32)
        
        self.contentView.addSubview(containerView)
        containerView.backgroundColor = .red
        containerView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0,
                                                                  left: 0,
                                                                  bottom: 0,
                                                                  right: 0))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Methods
    
    public func display(data: DiaryNoteItem, buttonPressedCallback: @escaping NotificationCallback) {
        self.buttonPressedCallback = buttonPressedCallback
        
        self.updateNoteTitle(data.title ?? "")
        self.updateNoteDescription(data.body ?? "")
        
        let noteType = data.diaryNoteType
        switch noteType {
        case .text:
            noteImageView.image = ImagePalette.image(withName: .textNoteListImage)
        case .audio:
            noteImageView.image = ImagePalette.image(withName: .audioNoteListImage)
        default:
            noteImageView.image = UIImage()
        }
    }
    
    // MARK: - Actions
    
    @objc private func buttonPressed() {
        self.buttonPressedCallback?()
    }
    
    // MARK: - Private Methods
    
    private func updateNoteTitle(_ title: String) {
        let attributedString = NSAttributedString.create(withText: title,
                                                         fontStyle: .paragraph,
                                                         colorType: .primaryText,
                                                         textAlignment: .left,
                                                         underlined: false)
        
        self.noteTitleLabel.attributedText = attributedString
    }
    
    private func updateNoteDescription(_ description: String) {
        let attributedString = NSAttributedString.create(withText: description,
                                                         fontStyle: .paragraph,
                                                         colorType: .primaryText,
                                                         textAlignment: .left,
                                                         underlined: false)
        
        self.noteDescriptionLabel.attributedText = attributedString
    }
}
