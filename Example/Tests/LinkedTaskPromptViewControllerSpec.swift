//
//  LinkedTaskPromptViewControllerSpec.swift
//  ForYouAndMe_Tests
//
//  Smoke specs for LinkedTaskPromptViewController — the custom modal shown
//  after a Quick Activity submission whose response carries a linked task id.
//
//  See FUAM-3037 / FUAM-3038.
//

import Quick
import Nimble
import UIKit
@testable import ForYouAndMe

class LinkedTaskPromptViewControllerSpec: QuickSpec {
    override func spec() {

        let sampleData = LinkedTaskPromptViewController.Data(
            title: "Hot Flashes",
            body: "Body copy",
            confirmButtonText: "Start now",
            cancelButtonText: "Skip"
        )

        describe("initialization") {

            it("uses overCurrentContext + crossDissolve so the panel overlays the presenter") {
                let vc = LinkedTaskPromptViewController(
                    data: sampleData,
                    onConfirm: {},
                    onCancel: {}
                )
                expect(vc.modalPresentationStyle) == .overCurrentContext
                expect(vc.modalTransitionStyle) == .crossDissolve
            }

            it("populates the view hierarchy on viewDidLoad") {
                let vc = LinkedTaskPromptViewController(
                    data: sampleData,
                    onConfirm: {},
                    onCancel: {}
                )
                vc.loadViewIfNeeded()
                expect(vc.view.subviews).toNot(beEmpty())
            }
        }

        describe("rendered content") {

            it("renders the title, body and both button labels from the supplied data") {
                let vc = LinkedTaskPromptViewController(
                    data: sampleData,
                    onConfirm: {},
                    onCancel: {}
                )
                vc.loadViewIfNeeded()

                let labels = vc.view.recursiveSubviews().compactMap { $0 as? UILabel }
                expect(labels.contains { $0.text == sampleData.title }).to(beTrue())

                let buttons = vc.view.recursiveSubviews().compactMap { $0 as? UIButton }
                let buttonTitles = buttons.compactMap { $0.attributedTitle(for: .normal)?.string }
                expect(buttonTitles).to(contain(sampleData.confirmButtonText))
                expect(buttonTitles).to(contain(sampleData.cancelButtonText))
            }
        }
    }
}

private extension UIView {
    func recursiveSubviews() -> [UIView] {
        return subviews + subviews.flatMap { $0.recursiveSubviews() }
    }
}
