fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build and upload to TestFlight

### ios release

```sh
[bundle exec] fastlane ios release
```

Build and upload to the App Store (metadata + binary)

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Capture App Store screenshots

### ios audit

```sh
[bundle exec] fastlane ios audit
```

Pre-submit audit: precheck sobre metadata del App Store

### ios tests

```sh
[bundle exec] fastlane ios tests
```

Unit tests only (sin UI tests)

### ios metadata

```sh
[bundle exec] fastlane ios metadata
```

Upload metadata + screenshots (textos, keywords, capturas)

### ios shots

```sh
[bundle exec] fastlane ios shots
```

Upload screenshots only

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
