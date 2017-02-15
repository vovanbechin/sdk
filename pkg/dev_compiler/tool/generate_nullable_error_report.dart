#!/usr/bin/env dart
// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Hacky script for generating a report of all of the static errors in the
/// (dev compiler fork of) the SDK. Using this to track getting the SDK to
/// be null-safe.
///
/// Assumes the working directory is dart/sdk/pkg/dev_compiler/.
///
/// NOTE! This uses the patched SDK in gen/patched_sdk. If you make changes to
/// tool/input_sdk, you need to regenerate the patched one before running this.
/// Use tool/patch_sdk.sh to do that.

import 'dart:io';

import 'package:front_end/src/base/errors.dart';

import 'package:dev_compiler/src/compiler/command.dart';
import 'package:dev_compiler/src/compiler/compiler.dart';

final webLibraries = [
    'dart:html',
    'dart:html_common',
    'dart:svg',
    'dart:web_audio',
    'dart:web_gl',
    'dart:web_sql'
].toSet();

main(List<String> arguments) {
  compile([
    '--unsafe-force-compile',
    '--no-source-map',
    '--no-emit-metadata',
    '--dart-sdk', 'gen/patched_sdk',
    '--dart-sdk-summary=build',
    '--summary-out', 'temp_ddc_sdk.sum',
    '--modules=amd', '-o', 'temp_dart_sdk.js',
    'dart:_runtime',
    'dart:_debugger',
    'dart:_foreign_helper',
    'dart:_interceptors',
    'dart:_internal',
    'dart:_isolate_helper',
    'dart:_js_embedded_names',
    'dart:_js_helper',
    'dart:_js_mirrors',
    'dart:_js_primitives',
    'dart:_metadata',
    'dart:_native_typed_data',
    'dart:async',
    'dart:collection',
    'dart:convert',
    'dart:core',
    'dart:developer',
    'dart:io',
    'dart:isolate',
    'dart:js',
    'dart:js_util',
    'dart:math',
    'dart:mirrors',
    'dart:typed_data',
    'dart:indexed_db',
    'dart:html',
    'dart:html_common',
    'dart:svg',
    'dart:web_audio',
    'dart:web_gl',
    'dart:web_sql'
  ], printFn: (message) {
    // Don't print anything. We'll print ourself below.
  });

  Hack.errors.sort((a, b) {
    // Sort by library.
    if (a.source.uri.toString() != b.source.uri.toString()) {
      return a.source.uri.toString().compareTo(b.source.uri.toString());
    }

    // Then by position.
    if (a.offset != b.offset) {
      return a.offset.compareTo(b.offset);
    }

    // Then message.
    return a.message.compareTo(b.message);
  });

  var messages = <String>[];

  for (var error in Hack.errors) {
    if (error.errorCode.errorSeverity == ErrorSeverity.INFO) continue;

    // TODO(rnystrom): Hack. The code generator for the HTML libraries produces
    // a bunch of fields marked external instead of external getters, which is
    // what they really are. We don't care about errors related to those.
    if (webLibraries.contains(error.source.uri.toString()) &&
        error.message.contains("must be initialized.")) {
      continue;
    }

    var lineInfo = Hack.context.computeLineInfo(error.source);
    var location = lineInfo.getLocation(error.offset);

    messages.add("${error.source.uri} "
        "(${location.lineNumber}:${location.columnNumber}) "
        "${error.message}");
  }

  messages.add("${messages.length} total errors.");
  print("${messages.length} total errors.");

  var file = new File('tool/nullable_sdk_errors.txt');
  file.writeAsStringSync(messages.join('\n'));

  new File("temp_dart_sdk.js").deleteSync();
  new File("temp_ddc_sdk.sum").deleteSync();
}
