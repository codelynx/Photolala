# Simple Cross-Platform Testing Scenario

## Test Flow: macOS → iOS

### Step 1: Clean Setup
```bash
# Clear S3 bucket (if needed)
# Remove any existing app data on both devices
```

### Step 2: macOS - Initial Setup & Upload

1. **Launch Photolala on macOS**
   - Fresh launch (no existing user)

2. **Sign Up with Apple ID**
   - From welcome screen, you'll see either:
     - "Sign In" button (if you have the older UI)
     - "Create Account" button (if you have the newer UI)
   - Click whichever button is available
   - Choose "Sign in with Apple"
   - Complete Apple ID authentication
   - For first-time users, this will create a new account
   - Verify account created successfully (check for user info display)

3. **Browse Local Photos**
   - Open a folder with photos (File → Open Folder or ⌘O)
   - Verify photos display correctly

4. **Star Photos for Backup**
   - Select 3-5 photos
   - Press 'S' key or use star button to star them
   - Verify star indicator appears on photos

5. **Wait for Auto-Backup**
   - Wait 5 minutes for auto-backup to trigger
   - OR manually trigger backup (if available)
   - Check status bar for upload progress
   - Verify "Uploaded" status on starred photos

6. **Open Cloud Browser**
   - Window → Cloud Browser (⌘⌥B)
   - Verify uploaded photos appear
   - Note the photo count

### Step 3: iOS - Sign In & Verify

1. **Launch Photolala on iOS Simulator**
   - Fresh launch (no existing user)

2. **Sign In with Same Apple ID**
   - Tap "Sign In" from welcome screen
   - Choose "Sign in with Apple"
   - Use same Apple ID as macOS
   - Verify successful sign in

3. **Open Cloud Browser**
   - Navigate to Cloud Browser
   - Verify same photos appear as on macOS
   - Check photo count matches
   - Verify thumbnails load correctly

4. **Test Photo Viewing**
   - Tap on a photo to view full size
   - Verify photo loads correctly
   - Test swipe navigation between photos

### Expected Results

✅ **Account Consistency**
- Same user ID on both platforms
- Apple ID recognized on both devices

✅ **Data Sync**
- Photos starred on macOS appear in iOS Cloud Browser
- Same number of photos on both platforms
- Metadata (filenames, dates) consistent

✅ **S3 Verification**
Check S3 bucket for:
- `identities/{userId}/user.json` - User identity file
- `photos/{userId}/` - Uploaded photo files
- `thumbnails/{userId}/` - Generated thumbnails

### Verification Commands

```bash
# Check S3 for user identity
aws s3 ls s3://photolala/identities/

# Check uploaded photos
aws s3 ls s3://photolala/photos/{userId}/

# Download and verify user.json
aws s3 cp s3://photolala/identities/{userId}/user.json ./
cat user.json
```

### What to Look For

1. **user.json should contain:**
   - Correct email from Apple ID
   - Provider: "apple"
   - Provider ID from Apple
   - Service User ID (UUID)

2. **Photo files in S3:**
   - Original photos uploaded
   - Correct file structure
   - Proper permissions

### Common Issues to Watch

1. **Sign In Issues:**
   - Apple ID not recognized
   - Different user IDs on different platforms
   - Authentication state not persisting

2. **Cloud Browser Issues:**
   - Photos not appearing
   - Thumbnails not loading
   - Slow performance

3. **S3 Issues:**
   - Missing identity file
   - Photos uploaded to wrong location
   - Permission errors

### Debug Tips

**macOS Console Output:**
- Look for: "Successfully uploaded to S3"
- Check for: "Identity saved to S3"

**iOS Console Output:**
- Look for: "Loaded identity from S3"
- Check for: "CloudPhotosProvider: Loaded X photos"

### Quick Test Summary

1. ✅ macOS: Sign up with Apple ID
2. ✅ macOS: Star 3-5 photos
3. ✅ macOS: Wait for upload / verify in Cloud Browser
4. ✅ iOS: Sign in with same Apple ID
5. ✅ iOS: Verify same photos in Cloud Browser
6. ✅ Both: Check S3 for proper data structure
