# Dependencies and resources

Leu's learning/semantic core remains dependency-free and does not run a language model, embedding model, vector database, or hosted AI service. Since V36 it bundles two data files derived from third-party work (see "Leu semantic space" below): a static word-vector table read by lookup and integer arithmetic, and a list of antonym pairs. The app target has one third-party runtime dependency in V24: Microsoft ONNX Runtime for optional on-device neural speech synthesis.

## Leu semantic space (V36)

`Packages/ShelfCore/Sources/ShelfCore/Resources/SemanticSpace/` holds data only; nothing in it executes, and no network is used to read it.

- `minilm-static-256.leusem` is a static WordPiece vector table distilled from the `sentence-transformers/all-MiniLM-L6-v2` model (published under the Apache License 2.0; its vocabulary is the uncased BERT WordPiece vocabulary, also Apache-2.0). It was produced offline by `scripts/build-semantic-space.py`: each vocabulary piece was encoded once by the model, the vectors were reduced to 256 dimensions by PCA and quantized to 8-bit integers. This is a modified derivative of the model's outputs, not the model itself; the model is not shipped and never runs in Leu. The input used was the ONNX export of the model distributed by the Chroma project. Review the upstream model card and the Apache-2.0 terms (a copy of the license and this notice of modification must accompany redistribution) before a public release.
- `wordnet-antonyms.txt` lists antonym pairs extracted from WordNet 3.0 by the same script. WordNet's license requires the following notice on all copies, including modifications:

> WordNet Release 3.0. This software and database is being provided to you, the LICENSEE, by Princeton University under the following license. By obtaining, using and/or copying this software and database, you agree that you have read, understood, and will comply with these terms and conditions.: Permission to use, copy, modify and distribute this software and database and its documentation for any purpose and without fee or royalty is hereby granted, provided that you agree to comply with the following copyright notice and statements, including the disclaimer, and that the same appear on ALL copies of the software, database and documentation, including modifications that you make for internal use or for distribution. WordNet 3.0 Copyright 2006 by Princeton University. All rights reserved. THIS SOFTWARE AND DATABASE IS PROVIDED "AS IS" AND PRINCETON UNIVERSITY MAKES NO REPRESENTATIONS OR WARRANTIES, EXPRESS OR IMPLIED. BY WAY OF EXAMPLE, BUT NOT LIMITATION, PRINCETON UNIVERSITY MAKES NO REPRESENTATIONS OR WARRANTIES OF MERCHANT- ABILITY OR FITNESS FOR ANY PARTICULAR PURPOSE OR THAT THE USE OF THE LICENSED SOFTWARE, DATABASE OR DOCUMENTATION WILL NOT INFRINGE ANY THIRD PARTY PATENTS, COPYRIGHTS, TRADEMARKS OR OTHER RIGHTS. The name of Princeton University or Princeton may not be used in advertising or publicity pertaining to distribution of the software and/or database. Title to copyright in this software, database and any associated documentation shall at all times remain with Princeton University and LICENSEE agrees to preserve same.

## ONNX Runtime

Leu pins `onnxruntime-swift-package-manager` to version `1.24.2`. ONNX Runtime is maintained by Microsoft and distributed under the MIT License. It is used only by the optional local speech renderer; it is not part of Leu Semantic Core and cannot generate questions, grade answers, infer feelings, or modify source truth.

## Supertonic 3

Leu can optionally download the archived Supertonic 3 ONNX speech assets from `supertone-oss-archive/supertonic-3`, pinned to model revision `aafc6e32416a594460b32413efc49d7fe4ce6d46`. The download is explicit from Settings and is approximately 400 MB. Once installed, synthesis is local; the runtime inference path has no network access. Apple speech remains the fallback when the assets are absent or unavailable.

The archived Supertonic sample/source code is MIT licensed. The Supertonic 3 model weights are separately licensed under OpenRAIL-M and carry use-based restrictions. Leu does not expose voice cloning or custom-speaker training. The upstream open-source repository is archived and no longer receives fixes or security support; this integration is therefore isolated behind `LeuSpeechEngine` so it can be replaced without changing Reader or Semantic Core behavior.

## Project resources

The portable SHA-256 fallback is project source validated against standard SHA-256 test vectors; on Apple platforms the digest adapter uses CryptoKit. It is not a replacement for encryption or signature verification.

The six small bundled PDFs are original study samples written for this project. Their diagrams and code illustrations are project resources, not copied commercial books. They cite relevant primary documentation in their pages. ReportLab was used during artifact production; it is not an app runtime dependency.

The launch icon and cover illustrations are original local drawings. The user's approved screenshot in `docs/approved-visual-reference.png` is retained as a private design reference, not advertised as a screenshot of this running build. Review its suitability before redistributing that reference publicly. System typefaces are requested by name/style from iOS; no font files are redistributed.
