# Phase 1 Testing Checklist - Unified Browser Architecture

## Test Date: 2025-06-21

### 1. PhotoBrowserView (Local Photos) Tests

#### Toolbar Functionality
- [ ] Display mode toggle works (aspect fit/fill)
- [ ] Item info toggle shows/hides info bar
- [ ] Thumbnail size picker changes sizes (S/M/L)
- [ ] Refresh button reloads photos
- [ ] Inspector button opens/closes inspector panel
- [ ] Sort picker works correctly
- [ ] Group picker works correctly
- [ ] Backup queue indicator shows if photos starred
- [ ] Preview button appears when photos selected
- [ ] S3 Backup button appears when photos selected (if enabled)

#### Inspector Panel
- [ ] Shows photo details (name, size, dimensions, date)
- [ ] Star toggle works
- [ ] Shows correct metadata
- [ ] Updates when selection changes
- [ ] Works with multiple selection

### 2. S3PhotoBrowserView (Cloud Photos) Tests

#### Toolbar Functionality
- [ ] Display mode toggle works (aspect fit/fill)
- [ ] Item info toggle shows/hides info bar
- [ ] Thumbnail size picker changes sizes (S/M/L)
- [ ] Refresh button syncs catalog
- [ ] Inspector button opens/closes inspector panel
- [ ] Offline indicator shows when offline
- [ ] Selection count displays correctly

#### Inspector Panel
- [ ] Shows S3 photo details (name, size, dimensions, date)
- [ ] Shows backup timestamp
- [ ] Shows archive status if archived
- [ ] Updates when selection changes
- [ ] Works with multiple selection

### 3. Cross-Browser Consistency

- [ ] Toolbar items appear in same order
- [ ] Common items behave identically
- [ ] Inspector layout is consistent
- [ ] Keyboard shortcuts work (if any)
- [ ] Visual appearance matches

### 4. Edge Cases

- [ ] Empty folders show correct UI
- [ ] Large selections work properly
- [ ] Rapid toolbar button clicks handled
- [ ] Window resizing preserves toolbar state
- [ ] Multiple windows work independently

### 5. Performance

- [ ] No lag when toggling inspector
- [ ] Toolbar updates are instant
- [ ] No memory leaks with repeated actions
- [ ] CPU usage normal

## Test Results

### PhotoBrowserView
- Status: 
- Notes: 

### S3PhotoBrowserView
- Status: 
- Notes: 

### Issues Found
1. 
2. 

### Summary
- Phase 1 implementation: 
- Ready for Phase 2: Yes/No