import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - macOS Header View

#if os(macOS)
class PhotoGroupHeaderView: NSView, NSCollectionViewElement {
	
	private let titleLabel = NSTextField()
	
	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		setupViews()
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		setupViews()
	}
	
	private func setupViews() {
		// Configure title label
		titleLabel.isEditable = false
		titleLabel.isBordered = false
		titleLabel.backgroundColor = .clear
		titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
		titleLabel.textColor = .labelColor
		titleLabel.alignment = .left
		
		// Add to view hierarchy
		addSubview(titleLabel)
		titleLabel.translatesAutoresizingMaskIntoConstraints = false
		
		NSLayoutConstraint.activate([
			titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
			titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
			titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
		])
		
		// Add background
		wantsLayer = true
		layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
	}
	
	func configure(with title: String) {
		titleLabel.stringValue = title
	}
	
	override func prepareForReuse() {
		super.prepareForReuse()
		titleLabel.stringValue = ""
	}
}

// Register as NSCollectionViewItem for easier use
class PhotoGroupHeaderItem: NSCollectionViewItem {
	override func loadView() {
		self.view = PhotoGroupHeaderView(frame: NSRect(x: 0, y: 0, width: 100, height: 40))
	}
	
	var headerView: PhotoGroupHeaderView? {
		return view as? PhotoGroupHeaderView
	}
}
#endif

// MARK: - iOS Header View

#if os(iOS)
class PhotoGroupHeaderView: UICollectionReusableView {
	
	static let reuseIdentifier = "PhotoGroupHeader"
	
	private let titleLabel = UILabel()
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		setupViews()
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		setupViews()
	}
	
	private func setupViews() {
		// Configure title label
		titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
		titleLabel.textColor = .label
		titleLabel.textAlignment = .left
		
		// Add to view hierarchy
		addSubview(titleLabel)
		titleLabel.translatesAutoresizingMaskIntoConstraints = false
		
		NSLayoutConstraint.activate([
			titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
			titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
			titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
		])
		
		// Add background
		backgroundColor = .systemGroupedBackground
	}
	
	func configure(with title: String) {
		titleLabel.text = title
	}
	
	override func prepareForReuse() {
		super.prepareForReuse()
		titleLabel.text = nil
	}
}
#endif