# Shared Resources

This directory contains resources shared between all platforms.

## Structure

```
shared/
├── Photos/                 # Sample photos for testing
├── icons/                  # App icons for all platforms
│   ├── ios/               # iOS app icons
│   ├── macos/             # macOS app icons
│   ├── android/           # Android app icons
│   └── source/            # Source icon files
└── assets/                # Other shared assets
    ├── colors/            # Color definitions
    └── fonts/             # Custom fonts (if any)
```

## Usage

### Photos
Sample photos are included for testing and demonstration purposes. These are referenced by both Apple and Android builds.

### Icons
Platform-specific icon sets are generated from source files. Use the appropriate icon set for each platform.

### Assets
Shared design assets that can be used across platforms. Consider platform-specific guidelines when using these assets.

## Icon Generation

To regenerate icons from source:
```bash
# TODO: Add icon generation script
```

## Adding New Resources

1. Place shared resources in appropriate subdirectory
2. Update platform-specific projects to reference new resources
3. Document any special usage requirements

See the main project README for more information.