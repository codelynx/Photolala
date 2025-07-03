#!/bin/bash
echo "Monitoring authentication logs..."
echo "Press Ctrl+C to stop"
echo "========================"
adb logcat | grep -E "GoogleAuthService|IdentityManager|Photolala|SignIn|OAuth"