// @flow

import type { SFSpeechRecognitionResult, SFSpeechAudioBufferRecognitionRequest } from '@talk-to-track/js-apple-dev';

type CallbackError = (err: Error) => void;
type CallbackResult = (result: SFSpeechRecognitionResult) => void;

export default (
  id: string,
  req: SFSpeechAudioBufferRecognitionRequest,
  cbResult?: CallbackResult,
  cbError?: CallbackError,
) => (
  global.cordova.exec(
    cbResult,
    cbError,
    'AppleSFSpeechRecognizerRecognitionTaskAudioBuffer',
    'start',
    [id, req],
  )
);
