# Solution for OAuth Android Client Already Exists Error

## The Issue
You have two Google Cloud projects:
1. `photolala` - Contains the Android OAuth client (created earlier)
2. `photolala-4b5ed` - Your current Firebase project

The Android OAuth client with package name `com.electricwoods.photolala` and SHA-1 `9B:E2:5F:F5:0A:1D:B9:3F:18:99:D0:FF:E2:3A:80:EF:5A:A7:FB:89` already exists in the `photolala` project.

## Solution Options

### Option 1: Use the Original Project (Recommended)
Switch everything to use the `photolala` project:

1. In the `photolala` project:
   - Create a Web OAuth client if it doesn't exist
   - Note down the Web Client ID
   - Download the google-services.json

2. Update your code:
   - Replace the Web Client ID in GoogleSignInLegacyService.kt
   - Replace android/app/google-services.json with the one from `photolala` project

### Option 2: Delete from Old Project
1. Go to the `photolala` project in Google Cloud Console
2. Navigate to APIs & Services → Credentials
3. Find the Android OAuth client with package name `com.electricwoods.photolala`
4. Delete it
5. Then create a new Android OAuth client in `photolala-4b5ed` project

### Option 3: Consolidate Projects
If you don't need two separate projects, consider:
1. Keeping only one project (either `photolala` or `photolala-4b5ed`)
2. Moving all OAuth clients to that single project
3. Updating Firebase to use the same project

## Quick Fix Steps
To quickly fix your current issue:

1. Click on the `photolala` project in the screenshot
2. Go to APIs & Services → Credentials
3. Check what OAuth clients exist there
4. Either:
   - Use that project's credentials (Option 1)
   - Delete the Android client to free up the package name (Option 2)