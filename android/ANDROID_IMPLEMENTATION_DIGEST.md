# Android Implementation Digest - Actionable Plan

Based on KY's review notes, here's a simplified, phased approach to Android development.

## Key Principles from Review
- **Step by step** - Don't implement everything at once
- **Small tasks** - Break complex features into manageable pieces  
- **POC when needed** - Create proof of concepts for uncertain areas
- **100K+ photos** - Target smooth browsing of large collections
- **Minimum features first** - Build core functionality before extras
- **Ask for decisions** - Consult when facing architectural choices

## Phase 1: Basic Photo Browsing (Week 1-2)

### 1.1 MediaStore Integration (Small Steps)
```
[ ] Create MediaStoreService interface
[ ] Implement basic photo query (just IDs and URIs)
[ ] Add pagination support (load 100 at a time)
[ ] Create simple test to verify it works
```

### 1.2 Simple Photo Grid UI
```
[ ] Create PhotoGridScreen composable
[ ] Use LazyVerticalGrid with fixed 3 columns
[ ] Display gray placeholders initially
[ ] Add pull-to-refresh
```

### 1.3 Thumbnail Loading with Coil
```
[ ] Configure Coil with memory/disk cache
[ ] Create PhotoThumbnail composable
[ ] Load thumbnails using MediaStore URI
[ ] Show loading indicator
```

### 1.4 Basic Navigation
```
[ ] Add Navigation Compose dependency (already added)
[ ] Create NavHost with 2 screens: Welcome, PhotoGrid
[ ] Simple "Browse Photos" button on Welcome
[ ] Back button handling
```

## Phase 2: Photo Viewer (Week 3)

### 2.1 Full Screen Photo View
```
[ ] Create PhotoViewerScreen
[ ] Implement pinch-to-zoom
[ ] Add swipe between photos
[ ] Show basic info (filename, size)
```

### 2.2 Navigation Integration
```
[ ] Navigate from grid to viewer on tap
[ ] Pass photo list and selected index
[ ] Implement shared element transition
```

## Phase 3: Services Layer (Week 4)

### 3.1 PhotoManager Service
```
[ ] Create interface first
[ ] Implement thumbnail generation
[ ] Add caching logic
[ ] Memory management for 100K+ photos
```

### 3.2 Repository Pattern
```
[ ] Create PhotoRepository interface
[ ] Implement with MediaStore + Room
[ ] Add simple in-memory cache
[ ] Test with large datasets
```

## Phase 4: Selection & Operations (Week 5)

### 4.1 Selection Mode
```
[ ] Long-press to start selection
[ ] Tap to select/deselect
[ ] Show selection count
[ ] Exit selection mode
```

### 4.2 Basic Operations
```
[ ] Share selected photos
[ ] Delete (move to trash)
[ ] Copy to folder
```

## POC List (Proof of Concepts)

### POC 1: Credential Storage
**Question**: What's the Kotlin equivalent of credential-code?
```
- Research Android Keystore API
- Test storing AWS credentials
- Create simple wrapper class
- Document security considerations
```

### POC 2: 100K Photo Performance
```
- Generate test dataset
- Measure scroll performance
- Test memory usage
- Optimize based on findings
```

### POC 3: Navigation Patterns
**Note**: "not confident, i prefer navigation"
```
- Try Navigation Compose with bottom nav
- Test drawer navigation
- Evaluate which feels better
- Get feedback before proceeding
```

### POC 4: Error Handling
```
- Create Result<T> wrapper
- Test network error scenarios  
- Design user-friendly messages
- Implement retry logic
```

## Questions to Answer

### What is Hilt?
- Google's dependency injection framework
- Built on top of Dagger
- Simplifies DI setup with annotations
- Already configured in the project

### Alternative to ViewModels?
- ViewModels are standard in Android
- Alternatives: MVI pattern, Redux-style
- Recommendation: Stick with ViewModels for now

### Kotlin Credential Storage?
- Android Keystore for secure storage
- EncryptedSharedPreferences for simpler data
- Need to evaluate based on security requirements

## Decision Points (Ask KY)

1. **Navigation Style**
   - Bottom navigation bar?
   - Navigation drawer?
   - Simple back stack?

2. **Photo Grid Layout**
   - Fixed 3 columns?
   - Adaptive based on screen size?
   - User adjustable like iOS?

3. **Caching Strategy**
   - How much disk space to use?
   - When to clear cache?
   - Thumbnail sizes?

4. **Error Messages**
   - Toast messages?
   - Snackbar?
   - Dialog boxes?

5. **Build Variants**
   - Need dev/staging/prod?
   - Different API endpoints?
   - Debug features?

## Next Immediate Action

Start with **Phase 1.1 - MediaStore Integration**:
1. Create MediaStoreService.kt interface
2. Implement getPhotos() returning Flow<List<PhotoMediaStore>>
3. Test with simple unit test
4. Move to next task

This approach ensures we build incrementally, test each piece, and don't get overwhelmed by the full scope.