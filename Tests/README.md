# JavaScript dialog regression tests

Open `DialogTests.xcodeproj` and run the shared `DialogTests` scheme on an iPhone or iPad simulator. No CocoaPods install or other dependencies are required. The test host compiles the library sources directly and uses the UIScene lifecycle.

From the repository root (replace the simulator name with an installed device):

```sh
xcodebuild -project Tests/DialogTests.xcodeproj -scheme DialogTests \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -parallel-testing-enabled NO test
```

The test targets require iOS 17 or newer to match Xcode 27's XCTest runtime. The library's podspec continues to support iOS 8; its scene APIs are guarded by availability checks.

Unit tests cover synchronous bridge prompts, custom delegate forwarding, exactly-once completions, nonblocking mode, custom labels/default input, detached views, concurrent dialogs, programmatic dismissal, existing alerts, and choosing the web view's own window even when another window is key. UI tests execute real JavaScript in WKWebView and select alert/confirm/prompt actions, edit prompt text, display consecutive dialogs, and verify nonblocking results.

The existing empty-string result for cancelling a blocking prompt is intentional. Nonblocking prompts still complete immediately with `nil` (JavaScript `null`). If a default dialog cannot be presented, it completes with its cancellation result instead of leaving JavaScript waiting.
