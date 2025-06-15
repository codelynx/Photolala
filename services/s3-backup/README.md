# S3 Photo Backup Service (Simplified)

## Philosophy

Start simple. Add complexity only when needed.

## What This Is

A basic way to backup photos from Photolala to AWS S3. Manual uploads only. No fancy features.

## Documentation Structure

- `design/` - Simple design document
- `requirements/` - What we're building (and what we're NOT)
- `api/` - API design (for later)
- `security/` - Security notes

## Current Status

🚧 **Design Phase** - Simplified approach defined

## Phase 1 Goals (MVP)

1. Connect to AWS S3
2. Upload a folder of photos
3. Track what's been uploaded
4. Show progress
5. That's it!

## What We're NOT Doing (Yet)

- ❌ Multiple providers (just AWS)
- ❌ Automatic backup
- ❌ Two-way sync
- ❌ Encryption
- ❌ iOS support
- ❌ Intel Macs
- ❌ Background uploads

## Technical Choices

- **Storage**: Simple JSON file (no database)
- **Platform**: macOS 14+ on Apple Silicon only
- **UI**: Basic SwiftUI view
- **Security**: macOS Keychain for credentials

## Next Steps

1. Review simplified design
2. Pick AWS SDK version
3. Build basic prototype
4. Test with real photos
5. Get user feedback