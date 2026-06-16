import CoreBluetooth
import Flutter
import PolarBleSdk
import UIKit

private let encoder = JSONEncoder()
private let decoder = JSONDecoder()

private func jsonEncode(_ value: Encodable) -> String? {
  guard let data = try? encoder.encode(value),
    let data = String(data: data, encoding: .utf8)
  else {
    return nil
  }

  return data
}

public class PolarPlugin:
  NSObject,
  FlutterPlugin,
  FlutterStreamHandler,
  PolarBleApiObserver,
  PolarBleApiPowerStateObserver,
  PolarBleApiDeviceFeaturesObserver,
  PolarBleApiDeviceInfoObserver
{
  /// Binary messenger for dynamic EventChannel registration
  let messenger: FlutterBinaryMessenger

  /// Method channel
  let methodChannel: FlutterMethodChannel

  /// Event channel
  let eventChannel: FlutterEventChannel

  /// Search channel
  let searchChannel: FlutterEventChannel

  /// Streaming channels
  var streamingChannels = [String: StreamingChannel]()

  var api: PolarBleApi!
  var sinks: [Int: FlutterEventSink] = [:]

  init(
    messenger: FlutterBinaryMessenger,
    methodChannel: FlutterMethodChannel,
    eventChannel: FlutterEventChannel,
    searchChannel: FlutterEventChannel
  ) {
    self.messenger = messenger
    self.methodChannel = methodChannel
    self.eventChannel = eventChannel
    self.searchChannel = searchChannel
  }

  private func initApi() {
    guard api == nil else { return }
    api = PolarBleApiDefaultImpl.polarImplementation(
      DispatchQueue.main, features: Set(PolarBleSdkFeature.allCases))

    api.observer = self
    api.powerStateObserver = self
    api.deviceFeaturesObserver = self
    api.deviceInfoObserver = self
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let methodChannel = FlutterMethodChannel(
      name: "polar/methods", binaryMessenger: registrar.messenger())
    let eventChannel = FlutterEventChannel(
      name: "polar/events", binaryMessenger: registrar.messenger())
    let searchChannel = FlutterEventChannel(
      name: "polar/search", binaryMessenger: registrar.messenger())

    let instance = PolarPlugin(
      messenger: registrar.messenger(),
      methodChannel: methodChannel,
      eventChannel: eventChannel,
      searchChannel: searchChannel)

    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    eventChannel.setStreamHandler(instance)
    searchChannel.setStreamHandler(instance.searchHandler)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    initApi()

    Task {
      do {
        switch call.method {
        case "connectToDevice":
          try api.connectToDevice(call.arguments as! String)
          result(nil)
        case "disconnectFromDevice":
          try api.disconnectFromDevice(call.arguments as! String)
          result(nil)
        case "getAvailableOnlineStreamDataTypes":
          try await getAvailableOnlineStreamDataTypes(call, result)
        case "getAvailableHrServiceDataTypes":
          try await getAvailableHrServiceDataTypes(call, result)
        case "requestStreamSettings":
          try await requestStreamSettings(call, result)
        case "createStreamingChannel":
          createStreamingChannel(call, result)
        case "startRecording":
          try await startRecording(call, result)
        case "stopRecording":
          try await stopRecording(call, result)
        case "requestRecordingStatus":
          try await requestRecordingStatus(call, result)
        case "listExercises":
          listExercises(call, result)
        case "fetchExercise":
          try await fetchExercise(call, result)
        case "removeExercise":
          try await removeExercise(call, result)
        case "setLedConfig":
          try await setLedConfig(call, result)
        case "doFactoryReset":
          try await doFactoryReset(call, result)
        case "enableSdkMode":
          try await enableSdkMode(call, result)
        case "disableSdkMode":
          try await disableSdkMode(call, result)
        case "isSdkModeEnabled":
          try await isSdkModeEnabled(call, result)
        case "doFirstTimeUse":
          try await doFirstTimeUse(call, result)
        case "isFtuDone":
          try await isFtuDone(call, result)
        default: result(FlutterMethodNotImplemented)
        }
      } catch {
        result(
          FlutterError(
            code: "Error in Polar plugin", message: error.localizedDescription, details: nil))
      }
    }
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    initApi()
    self.sinks[arguments as! Int] = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    guard let id = arguments as? Int else { return nil }
    self.sinks.removeValue(forKey: id)
    return nil
  }

  var searchTask: Task<Void, Never>?
  lazy var searchHandler = StreamHandler(
    onListen: { _, events in
      self.initApi()

      self.searchTask = Task {
        do {
            for try await data in self.api.searchForDevice() {
                guard let data = jsonEncode(PolarDeviceInfoCodable(data))
                else { continue }
                DispatchQueue.main.async {
                    events(data)
                }
            }
            DispatchQueue.main.async {
                events(FlutterEndOfEventStream)
            }
        } catch {
            DispatchQueue.main.async {
                events(
                    FlutterError(
                        code: "Error in searchForDevice", message: error.localizedDescription, details: nil)
                )
            }
        }
      }
      return nil
    },
    onCancel: { _ in
      self.searchTask?.cancel()
      return nil
    })

  private func createStreamingChannel(_ call: FlutterMethodCall, _ result: @escaping FlutterResult)
  {
    let arguments = call.arguments as! [Any]
    let name = arguments[0] as! String
    let identifier = arguments[1] as! String
    let feature = PolarDeviceDataType.allCases[arguments[2] as! Int]

    if streamingChannels[name] == nil {
      streamingChannels[name] = StreamingChannel(messenger, name, api, identifier, feature)
    }

    result(nil)
  }

  func getAvailableOnlineStreamDataTypes(
    _ call: FlutterMethodCall, _ result: @escaping FlutterResult
  ) async throws {
    let identifier = call.arguments as! String
    
    let data = try await api.getAvailableOnlineStreamDataTypes(identifier)
    guard let encodedData = jsonEncode(data.map { PolarDeviceDataType.allCases.firstIndex(of: $0)! }) else {
      result(FlutterError(code: "Unable to get available online stream data types", message: nil, details: nil))
      return
    }
    result(encodedData)
  }

  func getAvailableHrServiceDataTypes(
    _ call: FlutterMethodCall, _ result: @escaping FlutterResult
  ) async throws {
    let identifier = call.arguments as! String

    let data = try await api.getAvailableHRServiceDataTypes(identifier: identifier)
    guard let encodedData = jsonEncode(data.map { PolarDeviceDataType.allCases.firstIndex(of: $0)! }) else {
      result(FlutterError(code: "Unable to get available HR service data types", message: nil, details: nil))
      return
    }
    result(encodedData)
  }

  func requestStreamSettings(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) async throws {
    let arguments = call.arguments as! [Any]
    let identifier = arguments[0] as! String
    let feature = PolarDeviceDataType.allCases[arguments[1] as! Int]

    let data = try await api.requestStreamSettings(identifier, feature: feature)
    guard let encodedData = jsonEncode(PolarSensorSettingCodable(data)) else { return }
    result(encodedData)
  }

  func startRecording(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) async throws {
    let arguments = call.arguments as! [Any]
    let identifier = arguments[0] as! String
    let exerciseId = arguments[1] as! String
    let interval = RecordingInterval(rawValue: arguments[2] as! Int)!
    let sampleType = SampleType(rawValue: arguments[3] as! Int)!

    try await api.startRecording(
      identifier,
      exerciseId: exerciseId,
      interval: interval,
      sampleType: sampleType
    )
    result(nil)
  }

  func stopRecording(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) async throws {
    let identifier = call.arguments as! String

    try await api.stopRecording(identifier)
    result(nil)
  }

  func requestRecordingStatus(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) async throws {
    let identifier = call.arguments as! String

    let data = try await api.requestRecordingStatus(identifier)
    result([data.ongoing, data.entryId])
  }

  func listExercises(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let identifier = call.arguments as! String

    Task {
        do {
            var exercises = [String]()
            for try await data in api.listExercises(identifier) {
                guard let encodedData = jsonEncode(PolarExerciseEntryCodable(data)) else { continue }
                exercises.append(encodedData)
            }
            DispatchQueue.main.async { result(exercises) }
        } catch {
            DispatchQueue.main.async {
                result(FlutterError(code: "Error listing exercises", message: error.localizedDescription, details: nil))
            }
        }
    }
  }

  func fetchExercise(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) async throws {
    let arguments = call.arguments as! [Any]
    let identifier = arguments[0] as! String
    let entry = try! decoder.decode(
      PolarExerciseEntryCodable.self,
      from: (arguments[1] as! String).data(using: .utf8)!
    ).data

    let data = try await api.fetchExercise(identifier, entry: entry)
    guard let encodedData = jsonEncode(PolarExerciseDataCodable(data)) else { return }
    result(encodedData)
  }

  func removeExercise(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) async throws {
    let arguments = call.arguments as! [Any]
    let identifier = arguments[0] as! String
    let entry = try! decoder.decode(
      PolarExerciseEntryCodable.self,
      from: (arguments[1] as! String).data(using: .utf8)!
    ).data

    try await api.removeExercise(identifier, entry: entry)
    result(nil)
  }

  func setLedConfig(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) async throws {
    let arguments = call.arguments as! [Any]
    let identifier = arguments[0] as! String
    let config = try! decoder.decode(
      LedConfigCodable.self,
      from: (arguments[1] as! String).data(using: .utf8)!
    ).data
    
    try await api.setLedConfig(identifier, ledConfig: config)
    result(nil)
  }

  func doFactoryReset(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) async throws {
    let arguments = call.arguments as! [Any]
    let identifier = arguments[0] as! String
    let preservePairingInformation = arguments[1] as! Bool
    
    try await api.doFactoryReset(identifier, preservePairingInformation: preservePairingInformation)
    result(nil)
  }

  func enableSdkMode(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) async throws {
    let identifier = call.arguments as! String
    try await api.enableSDKMode(identifier)
    result(nil)
  }

  func disableSdkMode(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) async throws {
    let identifier = call.arguments as! String
    try await api.disableSDKMode(identifier)
    result(nil)
  }

  func isSdkModeEnabled(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) async throws {
    let identifier = call.arguments as! String
    let isEnabled = try await api.isSDKModeEnabled(identifier)
    result(isEnabled)
  }

  func doFirstTimeUse(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) async throws {
    let arguments = call.arguments as! [Any]
    let identifier = arguments[0] as! String
    let config = try! decoder.decode(
      PolarFirstTimeUseConfigCodable.self,
      from: (arguments[1] as! String).data(using: .utf8)!
    ).data

    try await api.doFirstTimeUse(identifier, ftuConfig: config)
    result(nil)
  }

  func isFtuDone(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) async throws {
    let identifier = call.arguments as! String

    let isDone = try await api.isFtuDone(identifier)
    result(isDone)
  }

  private func success(_ event: String, data: Any? = nil) {
    DispatchQueue.main.async {
      for sink in self.sinks {
        sink.value(["event": event, "data": data])
      }
    }
  }

  public func deviceConnecting(_ polarDeviceInfo: PolarDeviceInfo) {
    guard let data = jsonEncode(PolarDeviceInfoCodable(polarDeviceInfo))
    else {
      return
    }
    success("deviceConnecting", data: data)
  }

  public func deviceConnected(_ polarDeviceInfo: PolarDeviceInfo) {
    guard let data = jsonEncode(PolarDeviceInfoCodable(polarDeviceInfo))
    else {
      return
    }
    success("deviceConnected", data: data)
  }

  public func deviceDisconnected(_ polarDeviceInfo: PolarDeviceInfo, pairingError: Bool) {
    guard let data = jsonEncode(PolarDeviceInfoCodable(polarDeviceInfo))
    else {
      return
    }
    success("deviceDisconnected", data: [data, pairingError])
  }

  public func batteryLevelReceived(_ identifier: String, batteryLevel: UInt) {
    success("batteryLevelReceived", data: [identifier, batteryLevel])
  }

  public func batteryChargingStatusReceived(
    _ identifier: String, chargingStatus: BleBasClient.ChargeState
  ) {
    success(
      "batteryChargingStatusReceived", data: [identifier, String(describing: chargingStatus)])
  }

  public func batteryPowerSourcesStateReceived(
    _ identifier: String, powerSourcesState: BleBasClient.PowerSourcesState
  ) {
    // TODO
  }

  public func blePowerOn() {
    success("blePowerStateChanged", data: true)
  }

  public func blePowerOff() {
    success("blePowerStateChanged", data: false)
  }

  public func bleSdkFeatureReady(_ identifier: String, feature: PolarBleSdkFeature) {
    success(
      "sdkFeatureReady",
      data: [identifier, String(describing: feature)])
  }

  public func disInformationReceived(_ identifier: String, uuid: CBUUID, value: String) {
    success(
      "disInformationReceived", data: [identifier, uuid.uuidString, value])
  }

  public func disInformationReceivedWithKeysAsStrings(
    _ identifier: String, key: String, value: String
  ) {
    success("disInformationReceived", data: [identifier, key, value])
  }

  // MARK: Deprecated functions

  public func streamingFeaturesReady(
    _ identifier: String, streamingFeatures: Set<PolarBleSdk.PolarDeviceDataType>
  ) {
    // Do nothing
  }

  public func hrFeatureReady(_ identifier: String) {
    // Do nothing
  }

  public func ftpFeatureReady(_ identifier: String) {
    // Do nothing
  }
}

class StreamHandler: NSObject, FlutterStreamHandler {
  let onListen: (Any?, @escaping FlutterEventSink) -> FlutterError?
  let onCancel: (Any?) -> FlutterError?

  init(
    onListen: @escaping (Any?, @escaping FlutterEventSink) -> FlutterError?,
    onCancel: @escaping (Any?) -> FlutterError?
  ) {
    self.onListen = onListen
    self.onCancel = onCancel
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    return onListen(arguments, events)
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    return onCancel(arguments)
  }
}



class StreamingChannel: NSObject, FlutterStreamHandler {
  let api: PolarBleApi
  let identifier: String
  let feature: PolarDeviceDataType
  let channel: FlutterEventChannel

  var streamingTask: Task<Void, Never>?

  init(
    _ messenger: FlutterBinaryMessenger, _ name: String, _ api: PolarBleApi, _ identifier: String,
    _ feature: PolarDeviceDataType
  ) {
    self.api = api
    self.identifier = identifier
    self.feature = feature
    self.channel = FlutterEventChannel(name: name, binaryMessenger: messenger)

    super.init()

    channel.setStreamHandler(self)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    // Will be null for some features
    let settings = try? decoder.decode(
      PolarSensorSettingCodable.self,
      from: (arguments as! String)
        .data(using: .utf8)!
    ).data

    streamingTask = Task {
        do {
            switch feature {
            case .ecg:
                for try await data in api.startEcgStreaming(identifier, settings: settings!) {
                    handleData(data, events: events)
                }
            case .acc:
                for try await data in api.startAccStreaming(identifier, settings: settings!) {
                    handleData(data, events: events)
                }
            case .ppg:
                for try await data in api.startPpgStreaming(identifier, settings: settings!) {
                    handleData(data, events: events)
                }
            case .ppi:
                for try await data in api.startPpiStreaming(identifier) {
                    handleData(data, events: events)
                }
            case .gyro:
                for try await data in api.startGyroStreaming(identifier, settings: settings!) {
                    handleData(data, events: events)
                }
            case .magnetometer:
                for try await data in api.startMagnetometerStreaming(identifier, settings: settings!) {
                    handleData(data, events: events)
                }
            case .hr:
                for try await data in api.startHrStreaming(identifier) {
                    handleData(data, events: events)
                }
            case .temperature:
                for try await data in api.startTemperatureStreaming(identifier, settings: settings!) {
                    handleData(data, events: events)
                }
            case .pressure:
                for try await data in api.startPressureStreaming(identifier, settings: settings!) {
                    handleData(data, events: events)
                }
            case .skinTemperature:
                for try await data in api.startSkinTemperatureStreaming(identifier, settings: settings!) {
                    handleData(data, events: events)
                }
            }
            DispatchQueue.main.async {
                events(FlutterEndOfEventStream)
            }
        } catch {
            DispatchQueue.main.async {
                events(FlutterError(code: "Error while streaming", message: error.localizedDescription, details: nil))
            }
        }
    }

    return nil
  }
  
  private func handleData(_ data: Any, events: @escaping FlutterEventSink) {
    guard let encodedData = jsonEncode(PolarDataCodable(data)) else { return }
    DispatchQueue.main.async {
      events(encodedData)
    }
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    streamingTask?.cancel()
    return nil
  }

  func dispose() {
    streamingTask?.cancel()
    channel.setStreamHandler(nil)
  }
}
