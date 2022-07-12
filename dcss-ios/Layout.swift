//
//  Layout.swift
//  dcss-ios
//
//  Created by Jonathan Lazar on 11/25/21.
//

import Foundation
import UIKit

// MARK: - UI Utilities

extension UIView {
    @discardableResult
    func addAsSubview(to view: UIView) -> UIView {
        view.addSubview(self)
        return self
    }
}
