import AVFoundation
import Foundation
import Speech

@objc(AppleSFSpeechRecognizerRecognitionTaskAudioBuffer)
class AppleSFSpeechRecognizerRecognitionTaskAudioBuffer: CDVPlugin {
  var skipError = false
  var states: [String: (AVAudioEngine, SFSpeechAudioBufferRecognitionRequest, SFSpeechRecognitionTask)] = [:]

  override func pluginInitialize () {
    states = [:]
  }

  func stop(_ id: String) {
    if let state = self.states[id] {
      let audioSession = AVAudioSession.sharedInstance()
      let audioEngine = state.0
      let speechRecognitionRequest = state.1

      speechRecognitionRequest.endAudio()
      try? audioSession.setActive(false)

      if audioEngine.isRunning {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
      }

      states[id] = nil
    }
  }

  @objc(cancel:) func cancel(_ command: CDVInvokedUrlCommand) {
    self.skipError = true

    if command.arguments.count == 0 {
      return self.commandDelegate!.send(
        CDVPluginResult(status: CDVCommandStatus_ERROR),
        callbackId: command.callbackId
      )
    }

    guard let id = command.arguments[0] as? String else {
      return self.commandDelegate!.send(
        CDVPluginResult(status: CDVCommandStatus_ERROR),
        callbackId: command.callbackId
      )
    }

    guard let state = self.states[id] else {
      return self.commandDelegate!.send(
        CDVPluginResult(status: CDVCommandStatus_ERROR),
        callbackId: command.callbackId
      )
    }

    let speechRecognitionTask = state.2;
    speechRecognitionTask.cancel()

    self.commandDelegate!.send(
      CDVPluginResult(status: CDVCommandStatus_OK),
      callbackId: command.callbackId
    )
  }

  @objc(finish:) func finish(_ command: CDVInvokedUrlCommand) {
    self.skipError = true

    if command.arguments.count == 0 {
      return self.commandDelegate!.send(
        CDVPluginResult(status: CDVCommandStatus_ERROR),
        callbackId: command.callbackId
      )
    }

    guard let id = command.arguments[0] as? String else {
      return self.commandDelegate!.send(
        CDVPluginResult(status: CDVCommandStatus_ERROR),
        callbackId: command.callbackId
      )
    }

    guard let state = self.states[id] else {
      return self.commandDelegate!.send(
        CDVPluginResult(status: CDVCommandStatus_ERROR),
        callbackId: command.callbackId
      )
    }

    let speechRecognitionTask = state.2;
    speechRecognitionTask.finish()

    self.commandDelegate!.send(
      CDVPluginResult(status: CDVCommandStatus_OK),
      callbackId: command.callbackId
    )
  }

  @objc(start:) func start(_ command: CDVInvokedUrlCommand) {
    if command.arguments.count < 2 {
      return self.commandDelegate!.send(
        CDVPluginResult(status: CDVCommandStatus_ERROR),
        callbackId: command.callbackId
      )
    }

    guard let id = command.arguments[0] as? String else {
      return self.commandDelegate!.send(
        CDVPluginResult(status: CDVCommandStatus_ERROR),
        callbackId: command.callbackId
      )
    }

    guard let opts = command.arguments[1] as? [String: Any] else {
      return self.commandDelegate!.send(
        CDVPluginResult(status: CDVCommandStatus_ERROR),
        callbackId: command.callbackId
      )
    }

    guard let optsReq = opts["speechRecognitionRequest"] as? [String: Any] else {
      return self.commandDelegate!.send(
        CDVPluginResult(status: CDVCommandStatus_ERROR),
        callbackId: command.callbackId
      )
    }

    var localeId = ""

    if let optsRec = opts["speechRecognizer"] as? [String: Any] {
      if let optsRecLocaleId = optsRec["localeIdentifier"] as? String {
        localeId = optsRecLocaleId
      }
    }

    let speechRecognizerMaybe = localeId == "" ? SFSpeechRecognizer() : SFSpeechRecognizer(locale: Locale(identifier: localeId))

    guard let speechRecognizer = speechRecognizerMaybe else {
      return self.commandDelegate!.send(
        CDVPluginResult(status: CDVCommandStatus_ERROR),
        callbackId: command.callbackId
      )
    }

    let speechRecognitionRequest = SFSpeechAudioBufferRecognitionRequest()

    if let contextualStrs = optsReq["contextualStrings"] as? [String] {
      speechRecognitionRequest.contextualStrings = contextualStrs
    }

    if let interactionId = optsReq["interactionIdentifier"] as? String {
      speechRecognitionRequest.interactionIdentifier = interactionId
    }

    if let shouldReportPartialResults = optsReq["shouldReportPartialResults"] as? Bool {
      speechRecognitionRequest.shouldReportPartialResults = shouldReportPartialResults
    }

    if let taskHintRaw = optsReq["taskHint"] as? Int {
      if let taskHint = SFSpeechRecognitionTaskHint(rawValue: taskHintRaw) {
        speechRecognitionRequest.taskHint = taskHint
      }
    }

    let audioSession = AVAudioSession.sharedInstance()
    let audioEngine = AVAudioEngine()
    let audioInputNode = audioEngine.inputNode
    let audioFormat = audioInputNode.outputFormat(forBus: 0)

    try? audioSession.setCategory(AVAudioSession.Category.record, mode: AVAudioSession.Mode.measurement)
    try? audioSession.setActive(true)

    if let inputDataSourceId = optsReq["audioSessionDataSourceID"] as? NSNumber {
      if let sources = audioSession.inputDataSources {
        for source in sources {
          if source.dataSourceID === inputDataSourceId {
            try? audioSession.setInputDataSource(source)
            break
          }
        }
      }
    }

    self.skipError = true

    let speechRecognitionTask = speechRecognizer.recognitionTask(with: speechRecognitionRequest, resultHandler: { (speechRecognitionResult, speechRecognitionError) in
      if let error = speechRecognitionError {
        let serializedError = ["localizedDescription": error.localizedDescription]

        let pluginResult = CDVPluginResult(
          status: CDVCommandStatus_ERROR,
          messageAs: ["id": id, "value": serializedError]
        )

        self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
        return self.stop(id)
      }

      self.skipError = false

      if let result = speechRecognitionResult {
        let serializedTranscriptions = result.transcriptions.map({ transcription in [
          "formattedString": transcription.formattedString,
          "segments": transcription.segments.map({ segment in [
            "alternativeSubstrings": segment.alternativeSubstrings,
            "confidence": segment.confidence,
            "duration": segment.duration,
            "substring": segment.substring,
            "substringRange": [
              "length": segment.substringRange.length,
              "location": segment.substringRange.location
            ],
            "timestamp": segment.timestamp.magnitude
          ]})
        ]})

        let serializedSpeechRecognitionResult: [String: Any] = [
          "bestTranscription": serializedTranscriptions.count == 0 ? NSNull() : serializedTranscriptions[0],
          "isFinal": result.isFinal,
          "transcriptions": serializedTranscriptions
        ]

        let pluginResult = CDVPluginResult(
          status: CDVCommandStatus_OK,
          messageAs: [
            "id": id,
            "value": serializedSpeechRecognitionResult
          ]
        )

        pluginResult?.setKeepCallbackAs(true)
        self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)

        if result.isFinal {
          self.stop(id)
        }
      }
    })

    self.states[id] = (
      audioEngine,
      speechRecognitionRequest,
      speechRecognitionTask
    )

    audioInputNode.installTap(onBus: 0, bufferSize: 1024, format: audioFormat) {
      (buffer, time) in speechRecognitionRequest.append(buffer)
    }

    audioEngine.prepare()
    try? audioEngine.start()
  }
}
