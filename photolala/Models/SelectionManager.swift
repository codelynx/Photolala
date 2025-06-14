//
//  SelectionManager.swift
//  photolala
//
//  Created on 6/13/2025.
//

import Foundation
import Observation

/// Manages photo selection state for a window
@Observable
class SelectionManager {
	/// Currently selected photos
	private(set) var selectedItems: Set<PhotoReference> = []
	
	/// Anchor point for range selections (Shift+click/arrow)
	private(set) var anchorItem: PhotoReference?
	
	/// Currently focused item for keyboard navigation
	private(set) var focusedItem: PhotoReference?
	
	/// Number of selected items
	var selectionCount: Int {
		selectedItems.count
	}
	
	/// Whether any items are selected
	var hasSelection: Bool {
		!selectedItems.isEmpty
	}
	
	/// Check if an item is selected
	func isSelected(_ item: PhotoReference) -> Bool {
		selectedItems.contains(item)
	}
	
	/// Add item to selection
	func addToSelection(_ item: PhotoReference) {
		selectedItems.insert(item)
		anchorItem = item
		focusedItem = item
	}
	
	/// Remove item from selection
	func removeFromSelection(_ item: PhotoReference) {
		selectedItems.remove(item)
		if anchorItem == item {
			anchorItem = selectedItems.first
		}
		if focusedItem == item {
			focusedItem = anchorItem
		}
	}
	
	/// Toggle selection of an item (for Cmd+click or Space key)
	func toggleSelection(_ item: PhotoReference) {
		if isSelected(item) {
			removeFromSelection(item)
		} else {
			addToSelection(item)
		}
	}
	
	/// Add item to selection without changing anchor (used internally for range selection)
	private func addToSelectionWithoutAnchor(_ item: PhotoReference) {
		selectedItems.insert(item)
		focusedItem = item
	}
	
	/// Clear all selections
	func clearSelection() {
		selectedItems.removeAll()
		anchorItem = nil
		// Keep focus for keyboard navigation
	}
	
	/// Set single selection (clear others and set anchor)
	func setSingleSelection(_ item: PhotoReference) {
		selectedItems = [item]
		anchorItem = item
		focusedItem = item
	}
	
	/// Select range of items from anchor to target
	func selectRange(to: PhotoReference, in items: [PhotoReference]) {
		guard let anchor = anchorItem,
			  let fromIndex = items.firstIndex(of: anchor),
			  let toIndex = items.firstIndex(of: to) else {
			// No anchor, just select the target
			setSingleSelection(to)
			return
		}
		
		let range = min(fromIndex, toIndex)...max(fromIndex, toIndex)
		let itemsInRange = range.compactMap { items.indices.contains($0) ? items[$0] : nil }
		
		// Clear existing selection and set new range
		selectedItems.removeAll()
		selectedItems = Set(itemsInRange)
		focusedItem = to
		// Keep the original anchor - don't modify anchorItem
	}
	
	/// Update focused item without changing selection
	func setFocusedItem(_ item: PhotoReference?) {
		focusedItem = item
	}
	
	/// Debug helper
	func debugState() -> String {
		let selectedIndices = selectedItems.compactMap { $0.fileURL.lastPathComponent }
		let anchorName = anchorItem?.fileURL.lastPathComponent ?? "nil"
		let focusName = focusedItem?.fileURL.lastPathComponent ?? "nil"
		return "Selected: \(selectedIndices), Anchor: \(anchorName), Focus: \(focusName)"
	}
}