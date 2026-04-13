import Logging
import SwiftUI

@main
struct SpeechToTextApp: App {
  init() {
    LoggingSystem.bootstrap {
      var handler = StreamLogHandler.standardOutput(label: $0)
      handler.logLevel = .debug
      return handler
    }
  }

  var body: some Scene {
    WindowGroup {
      SpeechToTextView()
    }
  }
}
