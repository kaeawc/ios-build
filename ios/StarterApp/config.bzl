"""App identity and deployment targets for the Bazel build.

Change these when starting a new project (scripts/rename.sh does it for you). Until XcodeGen is
retired, keep them in sync with Configurations/Shared.xcconfig; deployment targets must also match
`platforms` in ios/Modules/Package.swift.
"""

APP_NAME = "StarterApp"
APP_DISPLAY_NAME = "StarterApp"
BUNDLE_ID_PREFIX = "com.example"
APP_BUNDLE_ID = BUNDLE_ID_PREFIX + "." + APP_NAME

# The watch app's bundle ID must start with the iOS app's.
WATCH_BUNDLE_ID = APP_BUNDLE_ID + ".watchkitapp"

MARKETING_VERSION = "1.0.0"
BUILD_NUMBER = "1"

IOS_MINIMUM_OS = "18.0"
TVOS_MINIMUM_OS = "18.0"
VISIONOS_MINIMUM_OS = "2.0"
WATCHOS_MINIMUM_OS = "11.0"
