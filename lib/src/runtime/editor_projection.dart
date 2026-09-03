// Copyright (C) 2026 Fiber
//
// This Source Code Form is subject to the terms of the Mozilla Public License,
// v. 2.0. If a copy of the MPL was not distributed with this file, You can
// obtain one at https://mozilla.org/MPL/2.0/.
//
// What you may do:
// - Use this software for any purpose, including commercially, and build and
//   sell your own products on top of it.
// - Change it, and create new works based on it.
// - Distribute copies of it, with or without your changes.
// - Combine it with files under any other licence, proprietary ones included,
//   and licence that larger work on your own terms.
//
// What you must do in return:
// - Keep this notice on every file you received it on.
// - Publish, under these same terms, the source of every file covered by them
//   that you distribute, including the ones you changed, so that whoever
//   receives your version can obtain that source.
// - Leave Fiber out of it: the name "Fiber", its branding, its logos and its
//   trademarks may not be used to endorse or promote what you build, and this
//   licence grants no right to them.
//
// Disclaimer:
// AS FAR AS THE LAW ALLOWS, THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY
// OR CONDITION OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR
// NON-INFRINGEMENT. IN NO EVENT SHALL FIBER BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT
// LIMITED TO LOSS OF USE, DATA, PROFITS, OR BUSINESS INTERRUPTION) ARISING OUT
// OF OR RELATED TO THESE TERMS OR THE USE OR NATURE OF THE SOFTWARE, UNDER ANY
// KIND OF LEGAL CLAIM.
//
// This header is a summary written for convenience. Where it differs from the
// LICENSE file, the LICENSE file governs.

/// What an editor needs to do so `@scribe/...` resolves for one runtime's packages.
///
/// A runtime with a dedicated language server extension, `deno`, answers with
/// [languageServer] and nothing written to disk. A runtime a stock TypeScript language
/// server already reads once it finds the right file on its own, `bun`, answers with
/// [filesWritten] and no [languageServer] at all: there is nothing for an editor to
/// configure, the file it already wrote is enough.
class EditorProjection {
  /// Records what a runtime's projection left behind.
  const EditorProjection({this.languageServer, this.filesWritten = const <String>[]});

  /// What to configure in the editor's own settings, or null when this runtime has no
  /// dedicated language server to point at anything.
  final LanguageServerProjection? languageServer;

  /// The paths of every file this projection wrote to disk on its own, empty when it wrote none.
  final List<String> filesWritten;
}

/// What one runtime's language server needs from an editor to answer `@scribe/...` correctly.
///
/// Nothing here is written to disk by the runtime itself: [configContents] travels back to the
/// caller, because only the caller, never this tool, knows where its own editor keeps files that
/// are not meant to be committed.
class LanguageServerProjection {
  /// Records what one runtime's language server needs.
  const LanguageServerProjection({
    required this.runtime,
    required this.extensionId,
    required this.enableSettingKey,
    required this.configSettingKey,
    required this.additionalSettings,
    required this.configFileName,
    required this.configContents,
    required this.restartCommands,
  });

  /// The runtime this projection answers for, the same word a manifest's `environment.runtime:`
  /// would write.
  final String runtime;

  /// The identifier of the editor extension driving this language server.
  final String extensionId;

  /// The editor setting that turns this language server on.
  final String enableSettingKey;

  /// The editor setting naming the file [configContents] is written to.
  final String configSettingKey;

  /// Settings beyond [enableSettingKey] and [configSettingKey] this language server needs, each
  /// value already shaped the way the editor's own settings expect it.
  final Map<String, Object> additionalSettings;

  /// The name a caller writes [configContents] under, in whatever storage it keeps for the file.
  final String configFileName;

  /// The file contents this language server reads its configuration from.
  final String configContents;

  /// The editor commands, tried in order, that make this language server read the settings just
  /// written instead of waiting for its own next poll.
  final List<String> restartCommands;
}
