// @flow

type Callback = (err?: Error) => void;

export default (id: string, cb: Callback) => (
  global.cordova.exec(
    () => cb(),
    err => cb(err),
    'AppleSFSpeechRecognizerRecognitionTaskAudioBuffer',
    'finish',
  )
);
