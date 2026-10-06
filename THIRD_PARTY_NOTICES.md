# Dependencies and resources

Leu's learning/semantic core remains dependency-free and does not use a language model, embedding model, vector database, or hosted AI service. The app target has one third-party runtime dependency in V24: Microsoft ONNX Runtime for optional on-device neural speech synthesis.

## ONNX Runtime

Leu pins `onnxruntime-swift-package-manager` to version `1.24.2`. ONNX Runtime is maintained by Microsoft and distributed under the MIT License. It is used only by the optional local speech renderer; it is not part of Leu Semantic Core and cannot generate questions, grade answers, infer feelings, or modify source truth.

## Supertonic 3

Leu can optionally download the archived Supertonic 3 ONNX speech assets from `supertone-oss-archive/supertonic-3`, pinned to model revision `aafc6e32416a594460b32413efc49d7fe4ce6d46`. The download is explicit from Settings and is approximately 400 MB. Once installed, synthesis is local; the runtime inference path has no network access. Apple speech remains the fallback when the assets are absent or unavailable.

The archived Supertonic sample/source code is MIT licensed. The Supertonic 3 model weights are separately licensed under OpenRAIL-M and carry use-based restrictions. Leu does not expose voice cloning or custom-speaker training. The upstream open-source repository is archived and no longer receives fixes or security support; this integration is therefore isolated behind `LeuSpeechEngine` so it can be replaced without changing Reader or Semantic Core behavior.

## Project resources

The portable SHA-256 fallback is project source validated against standard SHA-256 test vectors; on Apple platforms the digest adapter uses CryptoKit. It is not a replacement for encryption or signature verification.

The six small bundled PDFs are original study samples written for this project. Their diagrams and code illustrations are project resources, not copied commercial books. They cite relevant primary documentation in their pages. ReportLab was used during artifact production; it is not an app runtime dependency.

The launch icon and cover illustrations are original local drawings. The user's approved screenshot in `docs/approved-visual-reference.png` is retained as a private design reference, not advertised as a screenshot of this running build. Review its suitability before redistributing that reference publicly.

The Home scene (the daybed, quilt and tea) is an original Blender render made for this project, and the rainy city behind the window is an original procedural painting. Neither is derived from third-party artwork.

## Typefaces

Leu bundles static instances of two typefaces as data assets in `Shelf/Resources/Assets.xcassets/Fonts`, cut from the upstream variable fonts and subset to Latin:

- **Gabarito** (Regular through Black), Copyright 2023 The Gabarito Project Authors (https://github.com/naipefoundry/gabarito).
- **Literata** (Regular, Medium, SemiBold, Italic), Copyright 2017 The Literata Project Authors (https://github.com/googlefonts/literata).

Both are licensed under the SIL Open Font License, Version 1.1 (https://openfontlicense.org). The fonts are bundled with the app and are not sold on their own, and neither licence declares a Reserved Font Name. The full licence text ships alongside them in `docs/licenses/OFL-Gabarito.txt` and `docs/licenses/OFL-Literata.txt`. System monospace is still requested from iOS for code and coordinates.
