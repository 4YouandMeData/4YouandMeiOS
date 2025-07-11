//
//  ImageZoomViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 10/07/25.
//

class ImageZoomViewController: UIViewController, UIScrollViewDelegate {

    private let image: UIImage

    init(image: UIImage) {
        self.image = image
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .fullScreen
        self.modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .black

        let scrollView = UIScrollView()
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        self.view.addSubview(scrollView)
        scrollView.autoPinEdgesToSuperviewEdges()

        let imageView = UIImageView(image: self.image)
        imageView.contentMode = .scaleAspectFit
        scrollView.addSubview(imageView)
        imageView.autoPinEdgesToSuperviewEdges()
        imageView.autoMatch(.width, to: .width, of: scrollView)
        imageView.autoMatch(.height, to: .height, of: scrollView)

        // Close button
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(dismissView), for: .touchUpInside)
        self.view.addSubview(closeButton)
        closeButton.autoPinEdge(toSuperviewSafeArea: .top, withInset: 0)
        closeButton.autoPinEdge(toSuperviewSafeArea: .leading, withInset: 20)

        // Optional: "Pinch to zoom" indicator
        
        let hintImageView = UIImageView(image: ImagePalette.image(withName: .pinchZoom))
        hintImageView.contentMode = .scaleAspectFit
        hintImageView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(hintImageView)
        
        let zoomHint = UILabel()
        zoomHint.text = "Pinch to zoom"
        zoomHint.textColor = .white
        zoomHint.font = UIFont.systemFont(ofSize: 14)
        zoomHint.textAlignment = .center
        zoomHint.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(zoomHint)
        hintImageView.autoAlignAxis(toSuperviewAxis: .vertical)
        hintImageView.autoPinEdge(.bottom, to: .top, of: zoomHint, withOffset: -8)
        hintImageView.autoSetDimensions(to: CGSize(width: 40, height: 40))

        zoomHint.autoPinEdge(toSuperviewEdge: .bottom, withInset: 40)
        zoomHint.autoAlignAxis(toSuperviewAxis: .vertical)
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return scrollView.subviews.first
    }

    @objc private func dismissView() {
        self.dismiss(animated: true, completion: nil)
    }
}
