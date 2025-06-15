//
//  ClickedCollectionView.swift
//  Photolala
//
//  Created by Claude on 2025/06/15.
//

import AppKit

/// Custom NSCollectionView that tracks which item was clicked for context menu support
class ClickedCollectionView: NSCollectionView {
	/// The index path of the item that was right-clicked
	var clickedIndexPath: IndexPath?
	
	override func menu(for event: NSEvent) -> NSMenu? {
		print("[ClickedCollectionView] menu(for:) called, event type: \(event.type)")
		
		// Reset clicked index
		clickedIndexPath = nil
		
		// Convert point to collection view coordinates
		let point = convert(event.locationInWindow, from: nil)
		print("[ClickedCollectionView] Click point: \(point)")
		
		// Find which item was clicked
		if let indexPath = indexPathForItem(at: point) {
			print("[ClickedCollectionView] Found item at indexPath: \(indexPath)")
			clickedIndexPath = indexPath
			
			// If clicked item isn't selected, select only it
			if !selectionIndexPaths.contains(indexPath) {
				print("[ClickedCollectionView] Item not selected, selecting it")
				deselectAll(nil)
				selectItems(at: Set([indexPath]), scrollPosition: [])
				// Force update the selection
				if let delegate = delegate as? PhotoCollectionViewController {
					delegate.collectionView(self, didSelectItemsAt: Set([indexPath]))
				}
			}
		} else {
			print("[ClickedCollectionView] No item at click point")
		}
		
		// Return the menu set on the collection view
		let menu = super.menu(for: event)
		print("[ClickedCollectionView] Returning menu: \(menu?.debugDescription ?? "nil")")
		return menu
	}
}