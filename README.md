# Swift Actor Reentrancy Demo

A runnable reproduction of a real token-refresh problem: two callers enter an actor around an `await`, start duplicate requests, and overwrite state. The second implementation stores the in-flight `Task` so both callers share one refresh.

## Requirements

- macOS 13 or later
- Xcode 16 / Swift 6 or later

## Run

```bash
git clone https://github.com/2252408699/swift-actor-reentrancy-demo.git
cd swift-actor-reentrancy-demo
swift run
```

The first run prints two API requests. The fixed run prints one.
