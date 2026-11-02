# Hörbrückenbauer

**A phone app that turns spoken German into text and an English translation, live, on the phone itself.**

> Hörbrückenbauer is a working name. This is an early showcase, built in two days: I set the direction and made the calls, with an AI coding assistant as my pair-programmer.

## What it does
You speak German near the phone. The phone shows the German text and an English translation, sentence by sentence. The speech model is inside the app. Translation uses Apple's on-device language pack, which the system downloads once. After that it worked in airplane mode in my test (one iPhone, one run). The app's own code makes no network calls.

## Live listening
Use it only where everyone present agrees to be listened to. Audio stays in memory and is never saved.

## The self-test button
The app speaks six known German sentences with the phone's own voice, runs them through the same steps as live listening, and shows pass or fail, how many words were right, and the time. In the last run on one iPhone, all 6 sentences passed, and the model needed about a tenth of the sentence time. The limit: these are six clean sentences from one system voice, with no microphone. There is no accuracy number for real people or for noise yet.

## What went wrong (and how it was found)
- **Live listening was deaf.** My first sentence finder needed a loudness that phone recordings often do not reach. On 11 recordings of speech it found something in 1. After the fix it found speech in 10 (the miss had no speech in it). I used the same recordings to make the fix, so this is a repair check, not a fair exam.
- **A result I could not trust.** I ran the self-test twice and read the result file from my computer, and the numbers were identical. I added a finish time to the file to be sure I was reading a fresh result.
- **A name check I threw away.** A first quick check of name ideas was wrong because of a bug in my own command.

## Built with
WhisperKit (MIT), the OpenAI Whisper small speech model converted for Core ML (MIT), its tokenizer files (Apache-2.0), and Apple's on-device frameworks. Not affiliated with or endorsed by OpenAI, Argmax or Apple. The model files are not part of this repository; `tools/fetch_model.py` downloads them from their public sources. Full notices: `THIRD_PARTY_NOTICES.md`.

## Privacy
The app itself saves only the self-test result file (sentences and scores). It records no audio. The system may keep its own cache for the speech model.

## Build
```
python3 tools/fetch_model.py            # once: fetches the speech model into Models/
xcodegen generate
xcodebuild -project ShowcaseDemo.xcodeproj -scheme ShowcaseDemo -destination 'id=<device id>' -allowProvisioningUpdates -derivedDataPath build build
```
Copy `Local.xcconfig.example` to `Local.xcconfig` and fill in your own signing values. Computer-side checks: `tests/run.sh`.

## Licence and contact
MIT, see `LICENSE`. Questions and feedback: please open an issue.
