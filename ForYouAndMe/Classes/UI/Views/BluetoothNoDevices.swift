//
//  BluetoothNoDevices.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 19/03/25.
//

import UIKit

class BluetoothNoDevices: UIView {
    
    init(withTopOffset topOffset: CGFloat) {
        super.init(frame: .zero)
        
        self.backgroundColor = ColorPalette.color(withType: .secondary)
        
        let stackView = UIStackView.create(withAxis: .vertical, spacing: 16)
        self.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 24, left: 20.0, bottom: 0.0, right: 20.0),
                                               excludingEdge: .bottom)
        
        stackView.addImage(withImage: ImagePalette.image(withName: .bluetoothNoDevices),
                           color: .clear,
                           sizeDimension: 60)
        
        stackView.addLabel(withText: StringsProvider.string(
            forText: StringsProvider.string(forKey: .spiroNoDeviceTitle)),
                           fontStyle: .header2,
                           colorType: .primaryText)
        stackView.addBlankSpace(space: 20.0)
        stackView.addLabel(withText: StringsProvider.string(
            forText: StringsProvider.string(forKey: .spiroNoDeviceDesc)),
                           fontStyle: .paragraph,
                           colorType: .primaryText)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
