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
			self.setupViews()
		}

		required init?(coder: NSCoder) {
			super.init(coder: coder)
			self.setupViews()
		}

		private func setupViews() {
			// Configure title label
			self.titleLabel.isEditable = false
			self.titleLabel.isBordered = false
			self.titleLabel.backgroundColor = .clear
			self.titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
			self.titleLabel.textColor = .labelColor
			self.titleLabel.alignment = .left

			// Add to view hierarchy
			addSubview(self.titleLabel)
			self.titleLabel.translatesAutoresizingMaskIntoConstraints = false

			NSLayoutConstraint.activate([
				self.titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
				self.titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
				self.titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
			])

			// Add background
			wantsLayer = true
			layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
		}

		func configure(with title: String) {
			self.titleLabel.stringValue = title
		}

		override func prepareForReuse() {
			super.prepareForReuse()
			self.titleLabel.stringValue = ""
		}
	}

	// Register as NSCollectionViewItem for easier use
	class PhotoGroupHeaderItem: NSCollectionViewItem {
		override func loadView() {
			self.view = PhotoGroupHeaderView(frame: NSRect(x: 0, y: 0, width: 100, height: 40))
		}

		var headerView: PhotoGroupHeaderView? {
			view as? PhotoGroupHeaderView
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
			self.setupViews()
		}

		required init?(coder: NSCoder) {
			super.init(coder: coder)
			self.setupViews()
		}

		private func setupViews() {
			// Configure title label
			self.titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
			self.titleLabel.textColor = .label
			self.titleLabel.textAlignment = .left

			// Add to view hierarchy
			addSubview(self.titleLabel)
			self.titleLabel.translatesAutoresizingMaskIntoConstraints = false

			NSLayoutConstraint.activate([
				self.titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
				self.titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
				self.titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
			])

			// Add background
			backgroundColor = .systemGroupedBackground
		}

		func configure(with title: String) {
			self.titleLabel.text = title
		}

		override func prepareForReuse() {
			super.prepareForReuse()
			self.titleLabel.text = nil
		}
	}
#endif
