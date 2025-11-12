import Flutter
import UIKit

/// Forwards the Dart API of `responsly_sdk` to the Responsly iOS SDK, whose sources are compiled
/// into this module (the `ResponslySDK` folder, copied by `tool/sync_native.sh`).
///
/// One channel, both directions. Dart calls the SDK; the plugin calls Dart with the SDK's events
/// (the event's `toDictionary()` as arguments) and with display-guard questions. Everything here
/// runs on the main thread: Flutter delivers method calls there, and the SDK calls listeners and
/// the display guard there.
public final class ResponslySdkPlugin: NSObject, FlutterPlugin {
  private static let channelName = "responsly_sdk"
  private static let pendingGuardLifetime: TimeInterval = 10

  private let channel: FlutterMethodChannel
  private var listenerToken: ResponslyListenerToken?

  /// Dart has a handler for our calls. Until then nothing is sent to it.
  private var attached = false

  private var pendingGuards: [Int: (Bool) -> Void] = [:]
  private var nextGuardRequestId = 1

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(ResponslySdkPlugin(channel: channel), channel: channel)
  }

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
    // Every event goes to Dart as the SDK describes it.
    listenerToken = Responsly.shared.addListener(ResponslyListenerBlock(
      surveyShown: { [weak self] in self?.send("surveyShown", $0.toDictionary()) },
      surveyNotShown: { [weak self] in self?.send("surveyNotShown", $0.toDictionary()) },
      questionAnswered: { [weak self] in self?.send("questionAnswered", $0.toDictionary()) },
      surveyCompleted: { [weak self] in self?.send("surveyCompleted", $0.toDictionary()) },
      surveyDismissed: { [weak self] in self?.send("surveyDismissed", $0.toDictionary()) },
      surveyError: { [weak self] in self?.send("surveyError", $0.toDictionary()) }
    ))
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    if let token = listenerToken {
      Responsly.shared.removeListener(token)
      listenerToken = nil
    }
    attached = false
    // Nobody is left to answer; a guard that is still installed allows from now on.
    let waiting = pendingGuards.values
    pendingGuards = [:]
    waiting.forEach { $0(true) }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let arguments = Arguments(call)
    let sdk = Responsly.shared

    switch call.method {
    case "attach":
      attached = true
    case "initialize":
      guard let sdkKey = arguments.string("sdk_key") else {
        return result(arguments.missing("sdk_key"))
      }
      var options = ResponslyOptions()
      if let apiHost = arguments.string("api_host").flatMap(URL.init(string:)) {
        options.apiHost = apiHost
      }
      if let logLevel = arguments.string("log_level").flatMap(ResponslyLogLevel.init(name:)) {
        options.logLevel = logLevel
      }
      sdk.initialize(sdkKey: sdkKey, options: options)
    case "identify":
      guard let userId = arguments.string("user_id") else {
        return result(arguments.missing("user_id"))
      }
      sdk.identify(userId: userId, traits: ResponslyValue.traits(from: arguments.dictionary("traits")))
    case "setAttributes":
      sdk.setAttributes(ResponslyValue.traits(from: arguments.dictionary("traits")))
    case "track":
      guard let event = arguments.string("event") else {
        return result(arguments.missing("event"))
      }
      sdk.track(event, properties: ResponslyValue.properties(from: arguments.dictionary("properties")))
    case "screen":
      guard let name = arguments.string("name") else {
        return result(arguments.missing("name"))
      }
      sdk.screen(name)
    case "showSurvey":
      guard let surveyId = arguments.string("survey_id") else {
        return result(arguments.missing("survey_id"))
      }
      let options = ResponslyShowOptions(
        force: arguments.bool("force") ?? false,
        hiddenFields: arguments.stringDictionary("hidden_fields"),
        locale: arguments.string("locale"),
        presentation: arguments.string("presentation").flatMap(ResponslyPresentationStyle.init(rawValue:))
      )
      sdk.showSurvey(surveyId, options: options)
    case "closeSurvey":
      sdk.closeSurvey()
    case "pause":
      sdk.pause()
    case "resume":
      sdk.resume()
    case "setLocale":
      sdk.setLocale(arguments.string("locale"))
    case "setHiddenFields":
      sdk.setHiddenFields(arguments.stringDictionary("fields"))
    case "setTrackingEnabled":
      sdk.setTrackingEnabled(arguments.bool("enabled") ?? true)
    case "reset":
      sdk.reset()
    case "setDisplayGuard":
      if arguments.bool("enabled") == true {
        sdk.setDisplayGuard { [weak self] survey, decide in
          guard let self = self else { return decide(true) }
          self.askDart(survey, decide)
        }
      } else {
        sdk.setDisplayGuard(nil)
      }
    case "resolveDisplayGuard":
      if let requestId = arguments.int("request_id"),
        let decide = pendingGuards.removeValue(forKey: requestId)
      {
        decide(arguments.bool("allow") ?? true)
      }
    default:
      return result(FlutterMethodNotImplemented)
    }
    result(nil)
  }

  /// The SDK's display guard: asks Dart with a request id and keeps `decide` until Dart answers
  /// with `resolveDisplayGuard`. The SDK itself allows after 2 seconds without an answer.
  private func askDart(_ survey: ResponslySurvey, _ decide: @escaping (Bool) -> Void) {
    guard attached else { return decide(true) }
    let requestId = nextGuardRequestId
    nextGuardRequestId += 1
    pendingGuards[requestId] = decide
    send("displayGuard", ["request_id": requestId, "survey": survey.toDictionary()])
    // An answer this late is ignored by the SDK; only forget the request.
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.pendingGuardLifetime) { [weak self] in
      self?.pendingGuards[requestId] = nil
    }
  }

  private func send(_ method: String, _ arguments: [String: Any]) {
    guard attached else { return }
    channel.invokeMethod(method, arguments: arguments)
  }
}

/// Typed access to the arguments of a method call, which arrive as a loosely typed dictionary.
private struct Arguments {
  private let method: String
  private let values: [String: Any]

  init(_ call: FlutterMethodCall) {
    method = call.method
    values = call.arguments as? [String: Any] ?? [:]
  }

  func string(_ key: String) -> String? {
    values[key] as? String
  }

  func bool(_ key: String) -> Bool? {
    values[key] as? Bool
  }

  func int(_ key: String) -> Int? {
    (values[key] as? NSNumber)?.intValue
  }

  /// A map argument; a Dart `null` value arrives as `NSNull`.
  func dictionary(_ key: String) -> [String: Any] {
    values[key] as? [String: Any] ?? [:]
  }

  func stringDictionary(_ key: String) -> [String: String] {
    dictionary(key).compactMapValues { $0 as? String }
  }

  func missing(_ key: String) -> FlutterError {
    FlutterError(code: "invalid_arguments", message: "\(method) needs \(key)", details: nil)
  }
}
