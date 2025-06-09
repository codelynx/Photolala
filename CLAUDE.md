# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Photolala is an Xcode project for iOS/macOS development. The project is currently in its initial state with minimal configuration.

## Build Commands

Since this is an Xcode project, development is typically done through Xcode IDE:

```bash
# Build from command line
xcodebuild -project Photolala.xcodeproj -scheme Photolala build

# Clean build
xcodebuild -project Photolala.xcodeproj -scheme Photolala clean

# Run tests
xcodebuild -project Photolala.xcodeproj -scheme Photolala test
```

Note: The project currently has no targets defined, so these commands will need to be updated once targets are added.

## Project Structure

This is a standard Xcode project structure:
- `Photolala.xcodeproj/` - Xcode project configuration
- Source files will typically be organized in groups within Xcode

## Development Notes

- Development Team ID: 2P97EM4L4N
- The project supports both Debug and Release configurations
- No targets are currently defined in the project

## Development Process

Before implementing major features:
1. Create documentation in the `docs/` directory describing what will be implemented
2. Review and discuss the design
3. Wait for approval before proceeding with coding
4. Only start implementation after the documentation is approved