// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg/src/tools/did_command.dart';
import 'package:mocktail/mocktail.dart';

/// Saves the current state of the source code
class DidCommit extends DidCommand {
  /// Constructor
  DidCommit({
    required super.ggLog,
    super.name = 'commit',
    super.description = 'Informs if everything is committed.',
    super.shortDescription = 'Did commit',
    super.suggestion = 'Not committed yet. Please run »gg do commit«.',
    super.stateKey = 'doCommit',
  });
}

/// Mock for [DidCommit]
class MockDidCommit extends Mock implements DidCommit {}
