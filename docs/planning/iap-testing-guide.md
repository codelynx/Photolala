# IAP Testing Guide for Photolala

## Overview

This guide explains how to test the In-App Purchase (IAP) subscription system in Photolala.

## Setup Steps

### 1. Configure StoreKit for Local Testing (NO APPLE REGISTRATION NEEDED)

1. Open Photolala.xcodeproj in Xcode
2. Make sure "Photolala" scheme is selected in the toolbar
3. Click the scheme → "Edit Scheme..." (or press ⌘<)
4. In the dialog:
   - Select "Run" on the left
   - Click "Options" tab
   - Find "StoreKit Configuration"
   - Select `PhotolalaProducts.storekit` from dropdown
   - ✅ **CHECK THE CHECKBOX** next to the dropdown
5. Click "Close"
6. Run the app (⌘R)

**What this does**: 
- Uses the local `.storekit` file for products
- Bypasses Apple's servers completely
- No authentication needed
- Products load instantly

### IMPORTANT: Fixing "Loaded 0 products" Issue

If you see "Loaded 0 products" in the console:

1. **Sign out of App Store on Mac**:
   - System Settings → Sign In With Apple ID → Media & Purchases → Sign Out
   - This prevents conflicts with sandbox authentication

2. **Configure Xcode for StoreKit Testing**:
   - Edit Scheme → Run → Options
   - StoreKit Configuration: Select `PhotolalaProducts.storekit`
   - Check "Use the selected StoreKit configuration file"
   
3. **If using Sandbox (not local testing)**:
   - You need to sign in with a Sandbox Apple ID
   - The error "Finance Authentication Error" means you need to authenticate
   - Sign in through Settings → App Store → Sandbox Account

### 2. Create Sandbox Test Account (for device testing)

1. Sign in to [App Store Connect](https://appstoreconnect.apple.com)
2. Go to Users and Access → Sandbox Testers
3. Create a new test account with a unique email
4. Note: Sandbox accounts don't need to be real email addresses

### 3. Testing in Simulator

With the StoreKit configuration file:
1. Run the app in simulator
2. Go to View → IAP Test...
3. Products should load automatically
4. Click on any product to "purchase" (no real charges)
5. Transactions complete instantly in StoreKit testing mode

### 4. Testing on Device

1. Sign out of your real App Store account on device
2. Build and run the app on your device
3. When prompted during purchase, sign in with sandbox account
4. Purchases will go through Apple's sandbox servers

## Testing Scenarios

### Basic Flow
1. Launch app
2. View → Manage Subscription...
3. You'll see 4 subscription options
4. **To purchase**: Simply CLICK on any subscription tier
   - The subscription box acts as the purchase button
   - It will highlight when you hover
   - Click it to start the purchase
5. In local testing, the purchase completes instantly

### Alternative Flow (from S3 Backup)
1. View → S3 Backup...
2. Click "Sign in with Apple" (if not signed in)
3. Click the "Upgrade" button
4. This opens the same subscription view
5. Click on any subscription tier to purchase

### Subscription Management
1. View → Manage Subscription...
2. View current plan status
3. Upgrade/downgrade between tiers
4. Test family sharing (Family plan only)

### Quota Testing
1. Sign in with free account (5GB)
2. Try uploading large files
3. Verify quota exceeded error
4. Upgrade subscription
5. Verify increased quota

## Debug Tools

### IAP Developer Tools (NEW - Consolidated Interface)
Access via Photolala → Developer Tools → IAP Developer Tools... (DEBUG builds only)

**Features:**
- **Status Tab**: View user status, IAP status, and debug info
- **Products Tab**: See all available products and purchase status
- **Actions Tab**: Quick actions for testing including:
  - Open Subscription View
  - Refresh Products
  - Restore Purchases
  - Check Transaction Status
  - View Receipt (with detailed explanations)
  - Print Debug Info to console

### Console Logging
Watch Xcode console for:
- Product loading status
- Transaction states
- Receipt validation
- Error messages
- Debug output from "Print Debug Info" action

## Common Issues

### Products Not Loading
- Verify StoreKit configuration is selected in scheme
- Check bundle ID matches: com.electricwoods.photolala
- Ensure product IDs match those in IAPManager.swift
- **Sign out of real App Store account** to avoid conflicts

### "Finance Authentication Error" in Console
This error means StoreKit is trying to use sandbox but can't authenticate:
- **For Local Testing**: Make sure StoreKit Configuration is properly set in scheme
- **For Sandbox Testing**: Sign in with sandbox account in Settings
- The error is normal if you're not signed into sandbox - just use local testing

### Purchases Failing
- On device: Ensure signed into sandbox account
- Check internet connection
- Verify app capabilities include IAP

### Subscription Not Updating
- Call restore purchases
- Check transaction observer is active
- Verify receipt validation

## Quick Fix Steps (No Apple Portal Registration Needed!)

If you're seeing "Loaded 0 products" in your console:

1. **Stop the app** (⌘.)
2. **In Xcode**: Click on "Photolala" scheme in toolbar → **"Edit Scheme..."**
3. In the scheme editor:
   - Click **"Run"** on the left sidebar
   - Click **"Options"** tab at the top
   - Look for **"StoreKit Configuration"** section
   - From the dropdown, select **"PhotolalaProducts"** (it should show the .storekit file)
   - ✅ **IMPORTANT: Check the checkbox** to the left of the dropdown
   - The checkbox enables "Use the selected StoreKit configuration file"
4. Click **"Close"**
5. **Clean build folder**: Product → Clean Build Folder (⇧⌘K)
6. **Run the app again** (⌘R)

This will use **local StoreKit testing** which:
- ✅ Works without any Apple portal registration
- ✅ No sandbox account needed
- ✅ No App Store Connect setup required
- ✅ Products load from the `.storekit` file
- ✅ Purchases complete instantly (no real money)
- ✅ Perfect for development and testing

### How to Verify It's Working:

When properly configured, you should see:
- ✅ **Console**: "Loaded 4 products" (not "Loaded 0 products")
- ✅ **IAP Test menu** will show all 4 subscription tiers
- ✅ Products load instantly from the local .storekit file
- ✅ You can "purchase" subscriptions without real money

### How to Purchase in the UI:

In the Subscription View:
- Each subscription tier is displayed in a **clickable box**
- **Hover** over a tier - it will change appearance
- **Click the box** to purchase that tier
- There's no separate "Buy" button - the whole box is the button
- Already purchased tiers show a green checkmark

Note: You may still see some sandbox authentication errors in the console - these can be ignored when using local StoreKit testing, as the products will load from the local file.

**Important**: The errors you're seeing are because the app is trying to connect to Apple's servers. With local StoreKit testing enabled, it will use the PhotolalaProducts.storekit file instead.

## Production Setup

Before App Store submission:
1. Create products in App Store Connect
2. Submit products for review with app
3. Set up server-side receipt validation
4. Configure subscription status URL
5. Test with TestFlight

## Testing Subscription Tiers

### Free Tier (Default)
- 200MB storage (trial size)
- No subscription required
- Try before you buy

### Starter ($0.99/month)
- 500GB storage
- Store ~100,000 photos
- Perfect for getting started

### Essential ($1.99/month)
- 1TB storage
- Store ~200,000 photos
- Most popular choice

### Plus ($2.99/month)
- 1.5TB storage
- Store ~300,000 photos
- For serious photographers

### Family ($5.99/month)
- 1.5TB storage
- Share with 5 family members
- Same storage as Plus but shareable
- Best for families