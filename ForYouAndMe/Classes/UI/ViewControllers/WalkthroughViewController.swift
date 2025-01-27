//
//  WalkThroughViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 27/01/25.
//

import UIKit
import PureLayout

class WalkthroughViewController: UIViewController {
    
    // MARK: - UI Components
    
    private let scrollView = UIScrollView()
    private let pageControl = UIPageControl()
    
    // MARK: - Data Storage
    
    // We'll fill this array once we fetch and parse pages from the API
    var pages: [Page] = [] {
        didSet {
            self.setupUI()
        }
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        let buttonSkip = UIButton()
        buttonSkip.setTitle(StringsProvider.string(forKey: .surveyButtonSkip).uppercased(), for: .normal)
        buttonSkip.setTitleColor(ColorPalette.color(withType: .primary), for: .normal)
        buttonSkip.titleLabel?.font = FontPalette.fontStyleData(forStyle: .menu).font
        buttonSkip.addTarget(self, action: #selector(self.skipButtonPressed), for: .touchUpInside)
        
        self.view.addSubview(buttonSkip)
        buttonSkip.autoPinEdge(toSuperviewSafeArea: .trailing, withInset: 22)
        buttonSkip.autoPinEdge(toSuperviewSafeArea: .top, withInset: 30)
        
        self.setupScrollView()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // If you need to adjust the contentSize after rotation or layout changes:
        scrollView.contentSize = CGSize(
            width: view.bounds.width * CGFloat(pages.count),
            height: view.bounds.height
        )
    }
    
    // MARK: - Scroll View Setup
    
    private func setupScrollView() {
        // Enable horizontal paging
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = self
        
        // Add scrollView to the main view
        view.addSubview(scrollView)
        
        // Pin scrollView to all edges using PureLayout
        scrollView.autoPinEdgesToSuperviewEdges()
    }
    
    // MARK: - PageControl Setup
    
    private func setupPageControl() {
        pageControl.numberOfPages = self.pages.count
        pageControl.currentPage = 0
        pageControl.pageIndicatorTintColor = ColorPalette.color(withType: .inactive)
        pageControl.currentPageIndicatorTintColor = ColorPalette.color(withType: .primary)
        
        // Add the pageControl to the main view
        self.view.addSubview(pageControl)
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        
        // Position the pageControl at the bottom center
        pageControl.autoPinEdge(toSuperviewSafeArea: .bottom, withInset: 80.0)
        pageControl.autoAlignAxis(.vertical, toSameAxisOf: view)
    }
    
    // MARK: - UI Building
    
    private func setupPages() {
        // Create a subview in scrollView for each WalkthroughPage
        for (index, pageData) in pages.enumerated() {
            let pageContainer = UIView()
            scrollView.addSubview(pageContainer)
            
            // Use PureLayout to fix width/height and position horizontally
            pageContainer.autoSetDimension(.width, toSize: view.bounds.width)
            pageContainer.autoSetDimension(.height, toSize: view.bounds.height)
            
            pageContainer.autoPinEdge(.top, to: .top, of: scrollView)
            pageContainer.autoPinEdge(.left, to: .left, of: scrollView, withOffset: view.bounds.width * CGFloat(index))
            
            // Image
            let imageView = UIImageView()
            imageView.image = pageData.image
            imageView.contentMode = .scaleAspectFit
            
            pageContainer.addSubview(imageView)
            imageView.autoPinEdge(toSuperviewSafeArea: .top, withInset: 64.0)
            imageView.autoAlignAxis(toSuperviewAxis: .vertical)
            imageView.autoPinEdge(toSuperviewSafeArea: .leading)
            imageView.autoPinEdge(toSuperviewSafeArea: .trailing)
            imageView.autoSetDimension(.height, toSize: 400, relation: .lessThanOrEqual)
            
            // Title
            let titleLabel = UILabel()
            titleLabel.text = pageData.title
            titleLabel.textColor = ColorPalette.color(withType: .primaryText)
            titleLabel.textAlignment = .center
            titleLabel.font = FontPalette.fontStyleData(forStyle: .header2).font
            
            pageContainer.addSubview(titleLabel)
            titleLabel.autoPinEdge(toSuperviewSafeArea: .leading, withInset: 12.0)
            titleLabel.autoPinEdge(toSuperviewSafeArea: .trailing, withInset: 12.0)
            titleLabel.autoPinEdge(.top, to: .bottom, of: imageView, withOffset: 32.0)

            // Body
            let bodyLabel = UILabel()
            bodyLabel.attributedText = pageData.body.htmlToAttributedString
            bodyLabel.textColor = ColorPalette.color(withType: .primaryText)
            bodyLabel.textAlignment = .center
            bodyLabel.font = FontPalette.fontStyleData(forStyle: .paragraph).font
            
            pageContainer.addSubview(bodyLabel)
            bodyLabel.autoPinEdge(toSuperviewSafeArea: .leading, withInset: 12.0)
            bodyLabel.autoPinEdge(toSuperviewSafeArea: .trailing, withInset: 12.0)
            bodyLabel.autoPinEdge(.top, to: .bottom, of: titleLabel, withOffset: 12.0)
            bodyLabel.autoPinEdge(toSuperviewSafeArea: .bottom, withInset: 12.0, relation: .greaterThanOrEqual)
            
            // If it's the last page, add a "Close" button
            if index == pages.count - 1 {
                let closeButton = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false))
                closeButton.setButtonText("Start")
                closeButton.addTarget(target: self, action: #selector(closeButtonTapped))
                pageContainer.addSubview(closeButton)
                closeButton.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero, excludingEdge: .top)
            }
        }
    }
    
    /// Fetches remote pages from a JSON endpoint, then downloads images.
    private func setupUI() {
        // Update the pageControl number of pages
        self.pageControl.numberOfPages = self.pages.count
        // Build the UI for each page
        self.setupPages()
        self.setupPageControl()
        
        // Update scrollView content size after all subviews are laid out
        self.scrollView.contentSize = CGSize(
            width: self.view.bounds.width * CGFloat(self.pages.count),
            height: self.view.bounds.height
        )
    }
    
    // MARK: - Actions
    
    @objc private func skipButtonPressed() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true, completion: nil)
    }
}

// MARK: - UIScrollViewDelegate

extension WalkthroughViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Update the pageControl according to the scroll offset
        let pageIndex = round(scrollView.contentOffset.x / view.bounds.width)
        pageControl.currentPage = Int(pageIndex)
    }
}
