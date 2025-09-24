//
//  PhotoCell.swift
//  Photolala
//
//  Platform-specific collection view cell wrappers for PhotoCellView
//

import SwiftUI

#if os(macOS)
import AppKit

class PhotoCell: NSCollectionViewItem {
	static let reuseIdentifier = "PhotoCell"

	private var photoCellView: PhotoCellView {
		return view as! PhotoCellView
	}

	// Minimal loadView - just instantiate and assign
	override func loadView() {
		self.view = PhotoCellView()
	}

	// Pass-through to the view
	func configure(with item: PhotoBrowserItem, source: any PhotoSourceProtocol, displayMode: ThumbnailDisplayMode = .fill, showInfoBar: Bool = false) {
		photoCellView.configure(with: item, source: source, displayMode: displayMode, showInfoBar: showInfoBar)
	}

	override func prepareForReuse() {
		super.prepareForReuse()
		photoCellView.reset()
	}

	override var isSelected: Bool {
		didSet {
			photoCellView.setSelected(isSelected)
		}
	}
}

#else
import UIKit

class PhotoCell: UICollectionViewCell {
	static let reuseIdentifier = "PhotoCell"

	private let photoCellView = PhotoCellView()

	override init(frame: CGRect) {
		super.init(frame: frame)
		setupCell()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		setupCell()
	}

	private func setupCell() {
		// Add PhotoCellView as subview with full constraints
		photoCellView.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(photoCellView)

		NSLayoutConstraint.activate([
			photoCellView.topAnchor.constraint(equalTo: contentView.topAnchor),
			photoCellView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
			photoCellView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
			photoCellView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
		])
	}

	// Pass-through to the view
	func configure(with item: PhotoBrowserItem, source: any PhotoSourceProtocol, displayMode: ThumbnailDisplayMode = .fill, showInfoBar: Bool = false) {
		photoCellView.configure(with: item, source: source, displayMode: displayMode, showInfoBar: showInfoBar)
	}

	override func prepareForReuse() {
		super.prepareForReuse()
		photoCellView.reset()
	}

	override var isSelected: Bool {
		didSet {
			photoCellView.setSelected(isSelected)
		}
	}
}
#endif