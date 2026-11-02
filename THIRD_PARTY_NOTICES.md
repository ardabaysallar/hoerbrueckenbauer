# Third-party notices

```
  this repository ──► downloads speech model files and tokenizer files (not included here)
  the app ──► WhisperKit (MIT) and its Swift packages ──► runs the model on the phone
```

This is a working list, not legal advice. This project is not affiliated with or endorsed by OpenAI, Argmax or Apple. The repository contains no model, tokenizer or audio files. Anyone who builds and distributes the app must include these notices and the licence texts with it.

## Parts and licences
| Part | Use | Licence | Source |
|---|---|---|---|
| WhisperKit | runs the speech model on the phone | MIT, Copyright (c) 2024 argmax, inc. | github.com/argmaxinc/WhisperKit |
| Core ML conversion of OpenAI Whisper small (`openai_whisper-small`), unmodified | the speech model, downloaded by `tools/fetch_model.py` | MIT (model card) | huggingface.co/argmaxinc/whisperkit-coreml |
| Whisper small tokenizer files (`tokenizer.json`, `tokenizer_config.json`), unmodified | turns model output into text, downloaded by `tools/fetch_model.py` | Apache-2.0 (model card) | huggingface.co/openai/whisper-small |
| OpenAI Whisper (original model and code) | origin of the weights | MIT, Copyright (c) 2022 OpenAI | github.com/openai/whisper |
| Apple frameworks (Translation, AVFoundation, SwiftUI) | translation, audio, test speech, screens | Apple developer terms | developer.apple.com |

Note: the openai/whisper-small model card names the Apache-2.0 licence, while the openai/whisper code repository uses the MIT licence. Both are respected here.

## Swift packages that WhisperKit pulls in
swift-transformers, swift-argument-parser, swift-collections, swift-crypto, swift-asn1, swift-jinja, yyjson. Each package has its own licence file in its repository; they must be included in a distributed build.

## Licence texts
- MIT licence text (applies to WhisperKit, the Core ML conversion and OpenAI Whisper, each with its own copyright line above): see the `LICENSE` file of this repository for the exact wording, which is the standard MIT text.
- Apache-2.0 licence text for the tokenizer files: https://www.apache.org/licenses/LICENSE-2.0.txt. If the tokenizer files are redistributed, keep them unmodified, include this licence text and the source address above.
