---
description: Build Clarity for the iOS simulator and show only errors
---

Build the Clarity app for iOS Simulator and report the result.

!`xcodebuild -project Clarity.xcodeproj -scheme Clarity -sdk iphonesimulator -configuration Debug build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" | grep -v "warning:" | head -30`

If there are errors, explain each one and fix them. If BUILD SUCCEEDED, confirm it's ready to run.
