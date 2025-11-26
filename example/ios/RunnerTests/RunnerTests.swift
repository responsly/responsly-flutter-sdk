import Flutter
import UIKit
import XCTest

@testable import responsly_sdk

/// Unit tests of the Swift side of the plugin. The Dart tests in `test/` cover the channel
/// protocol; these only check that the plugin answers method calls.
class RunnerTests: XCTestCase {
  private func makePlugin() -> ResponslySdkPlugin {
    ResponslySdkPlugin(
      channel: FlutterMethodChannel(name: "responsly_sdk", binaryMessenger: StubMessenger()))
  }

  func testKnownMethodCompletesWithoutValue() {
    let answered = expectation(description: "result is called")
    makePlugin().handle(FlutterMethodCall(methodName: "attach", arguments: nil)) { result in
      XCTAssertNil(result)
      answered.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

  func testMissingArgumentIsAnError() {
    let answered = expectation(description: "result is called")
    makePlugin().handle(FlutterMethodCall(methodName: "screen", arguments: [String: Any]())) { result in
      XCTAssertEqual((result as? FlutterError)?.code, "invalid_arguments")
      answered.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

  func testUnknownMethodIsNotImplemented() {
    let answered = expectation(description: "result is called")
    makePlugin().handle(FlutterMethodCall(methodName: "nope", arguments: nil)) { result in
      XCTAssertTrue((result as AnyObject?) === FlutterMethodNotImplemented)
      answered.fulfill()
    }
    waitForExpectations(timeout: 1)
  }
}

private final class StubMessenger: NSObject, FlutterBinaryMessenger {
  func send(onChannel channel: String, message: Data?) {}

  func send(onChannel channel: String, message: Data?, binaryReply callback: FlutterBinaryReply?) {}

  func setMessageHandlerOnChannel(
    _ channel: String, binaryMessageHandler handler: FlutterBinaryMessageHandler?
  ) -> FlutterBinaryMessengerConnection {
    0
  }

  func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}
}
