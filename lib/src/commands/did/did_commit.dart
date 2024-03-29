// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg/src/tools/did_command.dart';

/// Saves the current state of the source code
class DidCommit extends DidCommand {
  /// Constructor
  DidCommit({
    required super.ggLog,
    super.name = 'commit',
    super.description = 'Informs if everything is committed.',
    super.question = 'Did run »gg do commit«?',
    super.predecessors = const [],
    super.isCommitted,
    super.headHash,
  });
}
