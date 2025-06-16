# Deep Archive User Experience Stories

## Overview
Deep Archive photos are stored at ultra-low cost but require 12-48 hours to retrieve. The UX must make this limitation clear while still providing value.

## User Story 1: Sarah's Wedding Photos

Sarah backed up her wedding photos from 3 years ago. They're now in Deep Archive.

### Browsing Experience
1. Sarah opens Photolala and sees all her photos via thumbnails
2. Wedding photos show a small "cloud + clock" badge in corner
3. She can browse, search, and organize normally using thumbnails
4. Metadata (date, location, camera) all available instantly

### Attempting to View Full Photo
1. Sarah clicks on a wedding photo
2. Instead of loading, she sees:
   ```
   ┌────────────────────────────────┐
   │     [Thumbnail displayed]       │
   │                                 │
   │    📦 Archived Photo            │
   │                                 │
   │ This photo is in deep storage   │
   │ to save costs. Retrieval takes  │
   │ 2-3 days.                       │
   │                                 │
   │ [Retrieve This Photo - $0.01]   │
   │ [Retrieve Album (45) - $0.50]   │
   │                                 │
   │ ℹ️ Photos remain available for   │
   │   30 days after retrieval       │
   └────────────────────────────────┘
   ```

### Retrieval Process
1. Sarah selects "Retrieve Album" 
2. Confirmation shows:
   - 45 photos, 450MB total
   - Cost: $0.50 (covered by your $2.00 monthly credit)
   - Available in 2-3 days
   - Email notification when ready
3. She confirms and sees progress indicator

### 24 Hours Later
1. Email: "Your wedding photos are ready!"
2. Opens Photolala - wedding photos no longer show archive badge
3. Can view, download, share normally
4. Banner shows: "Retrieved photos available until Feb 15"

## User Story 2: Quick Single Photo Need

Mike needs one specific photo for a presentation tomorrow.

### Discovery
1. Searches for "company picnic 2019"
2. Finds the photo but sees archive badge
3. Clicks and gets retrieval options:
   ```
   ┌────────────────────────────────┐
   │    ⚡ Expedited Retrieval       │
   │                                 │
   │  Standard (2-3 days) - $0.01    │
   │  ✓ Express (1 day) - $0.02      │
   │                                 │
   │  [Retrieve Now]                 │
   └────────────────────────────────┘
   ```
4. Selects Rush for important presentation

## User Story 3: Vacation Planning

The Chen family is creating a photo book from their 2018 Europe trip.

### Smart Retrieval
1. They search "Europe 2018" - 500 photos found
2. All show archive badges
3. They start selecting favorites using thumbnails
4. After selecting 50 photos, a banner appears:
   ```
   💡 Retrieve only selected photos (50) - $0.50
      Or retrieve entire trip (500) - $5.00
      
   Your Essential plan includes $2.00/mo credit
   Selected photos would be FREE!
   ```
5. They retrieve just their selections

## User Story 4: The Power User

David has 10TB of photos, mostly in Deep Archive.

### Dashboard View
```
┌─────────────────────────────────────┐
│  Storage Overview                   │
├─────────────────────────────────────┤
│  Total: 10TB                        │
│  ■■■■■■□□□□ Recent (1TB)           │
│  ■■■■■■■■■■ Archived (9TB)         │
│                                     │
│  Monthly Savings: $76.50            │
│  (vs keeping all photos accessible)  │
└─────────────────────────────────────┘
```

### Retrieval History
```
Recent Retrievals:
- Jan 5: Kids Birthday 2019 (30 photos) - $0.30 ✓
- Dec 20: Christmas 2017-2020 (400 photos) - $4.00 ✓
- Dec 1: Family Archives (50GB) - $6.00 - Expires in 5 days

Monthly credit used: $8.30 of $10.00
```

## UX Principles

### 1. Transparency
- Always show archive status clearly
- Display costs upfront
- Explain wait times

### 2. Batch Operations
- Encourage album/event retrieval over single photos
- Show cost savings for batch retrieval
- Smart suggestions based on metadata

### 3. Predictive Features
- "Retrieve for upcoming anniversary"
- "Christmas photos will archive in 30 days"
- Seasonal retrieval suggestions

### 4. Cost Awareness
```
Your Savings This Month:
Photos in Deep Archive: 8TB
Storage cost: $7.92 (was $32.00 in standard storage)
You saved: $24.08 on storage! 🎉

Retrieval this month: $12.50
Covered by credits: $10.00
You paid: $2.50
```

## Visual Indicators

### In Grid View
- Small "cloud + clock" badge on archived photos
- Slight opacity reduction (90%)
- Instant/archived count in folder info

### In Detail View  
- Clear "Archived" banner
- Retrieval options prominent
- Cost calculator for selections

### Smart Grouping
- "Recently Retrieved" smart album
- "Expiring Soon" for photos about to re-archive
- "Archive Candidates" for photos approaching 6mo/1yr

## Retrieval States

1. **Archived** - In Deep Archive
2. **Retrieving** - Request submitted, waiting
3. **Ready** - Available for viewing/download
4. **Expiring** - Will return to archive soon
5. **Active** - In standard storage (not archived)

## Notification System

### Email Notifications
- Retrieval started confirmation
- Retrieval ready alert
- 7 days before re-archiving warning
- Monthly savings report

### In-App Notifications
- Badge on app icon when photos ready
- Banner for expiring retrievals
- Celebration when saving milestones hit

## Settings & Preferences

```
Archive Settings:
□ Auto-archive after: [6 months ▼]
□ Keep starred photos accessible
□ Notify before archiving
□ Show cost estimates
□ Enable expedited retrieval

Retrieval Preferences:
□ Default to batch retrieval
□ Auto-extend popular retrievals
□ Low credit alert: [100 credits]
```