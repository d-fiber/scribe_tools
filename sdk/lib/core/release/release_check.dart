// Copyright (C) 2026 Fiber
//
// All rights reserved. This script, including its code and logic, is the
// exclusive property of Fiber. Redistribution, reproduction,
// or modification of any part of this script is strictly prohibited
// without prior written permission from Fiber.
//
// Conditions of use:
// - The code may not be copied, duplicated, or used, in whole or in part,
//   for any purpose without explicit authorization.
// - Redistribution of this code, with or without modification, is not
//   permitted unless expressly agreed upon by Fiber.
// - The name "Fiber" and any associated branding, logos, or
//   trademarks may not be used to endorse or promote derived products
//   or services without prior written approval.
//
// Disclaimer:
// THIS SCRIPT AND ITS CODE ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT. IN NO EVENT SHALL
// FIBER BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT LIMITED TO LOSS OF USE,
// DATA, PROFITS, OR BUSINESS INTERRUPTION) ARISING OUT OF OR RELATED TO THE USE
// OR INABILITY TO USE THIS SCRIPT, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Unauthorized copying or reproduction of this script, in whole or in part,
// is a violation of applicable intellectual property laws and will result
// in legal action.

import 'dart:convert';
import 'dart:io';

import 'release_source.dart';
import 'version.dart';

enum ReleaseState { upToDate, updateAvailable, ahead, unknown }

class ReleaseStatus {
  const ReleaseStatus({required this.state, this.local, this.remote});

  final ReleaseState state;
  final Version? local;
  final Version? remote;

  bool get needsUpdate => state == ReleaseState.updateAvailable;

  String describe() {
    switch (state) {
      case ReleaseState.updateAvailable:
        return 'scribe $remote is available, you are on $local. Run `koko-kernel upgrade` to update.';
      case ReleaseState.upToDate:
        return 'scribe $local is up to date.';
      case ReleaseState.ahead:
        return 'scribe $local is ahead of $remote on the published branch.';
      case ReleaseState.unknown:
        return 'Could not work out whether a newer scribe is available.';
    }
  }
}

class ReleaseCheck {
  const ReleaseCheck({
    required this.local,
    required this.cacheFile,
    this.remote = const RemoteRelease(),
    this.ttl = const Duration(hours: 12),
    this.now = DateTime.now,
  });

  final ReleaseSource local;
  final ReleaseSource remote;
  final File cacheFile;
  final Duration ttl;
  final DateTime Function() now;

  Future<ReleaseStatus> status({bool force = false}) async {
    final Version? installed = await _quietly(local.read);
    if (installed == null) return const ReleaseStatus(state: ReleaseState.unknown);

    final Version? published = force ? await _fetchAndCache() : (_cached() ?? await _fetchAndCache());
    if (published == null) {
      return ReleaseStatus(state: ReleaseState.unknown, local: installed);
    }

    final ReleaseState state;
    if (installed < published) {
      state = ReleaseState.updateAvailable;
    } else if (installed > published) {
      state = ReleaseState.ahead;
    } else {
      state = ReleaseState.upToDate;
    }

    return ReleaseStatus(state: state, local: installed, remote: published);
  }

  Version? _cached() {
    if (!cacheFile.existsSync()) return null;

    try {
      final Map<String, dynamic> payload = jsonDecode(cacheFile.readAsStringSync()) as Map<String, dynamic>;
      final DateTime checkedAt = DateTime.parse(payload['checkedAt'] as String);
      if (now().difference(checkedAt) > ttl) return null;

      return Version.tryParse(payload['version'] as String);
    } on Object {
      return null;
    }
  }

  Future<Version?> _fetchAndCache() async {
    final Version? published = await _quietly(remote.read);
    if (published == null) return null;

    try {
      cacheFile.parent.createSync(recursive: true);
      cacheFile.writeAsStringSync(
        jsonEncode(<String, String>{'checkedAt': now().toIso8601String(), 'version': published.toString()}),
      );
    } on Object {
      return published;
    }

    return published;
  }

  Future<Version?> _quietly(Future<Version?> Function() read) async {
    try {
      return await read();
    } on Object {
      return null;
    }
  }
}
