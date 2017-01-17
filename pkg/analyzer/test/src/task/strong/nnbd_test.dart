// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Hacky tests for the prototype implementation of non-nullable types. Unlike
// non_null_checker_test.dart, these are the newer ones that test *all* types
// supporting non-nullability.

import 'package:test/test.dart';

import '../strong/strong_test_helper.dart';

void main() {
  setUp(doSetUp);
  tearDown(doTearDown);

  testStatement(
      "initialize non-nullable local with null",
      'int i = /*error:INVALID_ASSIGNMENT*/null;');

  testStatement(
      "initialize Object local with null",
      'Object i = null;');

  testStatement(
      "initialize Null with null",
      'Null i = null;');

  testStatement(
      "initialize Null with other type",
      'Null i = /*error:INVALID_ASSIGNMENT*/123;');

  group("uninitialized local", () {
    // TODO(rnystrom): Better error message.
    testStatement(
        "non-nullable",
        'int /*error:NON_NULLABLE_FIELD_NOT_INITIALIZED*/i;');

    testStatement(
        "untyped",
        'var i;');

    testStatement(
        "nullable",
        'Object i;');

    testStatement(
        "dynamic",
        'dynamic i;');
  });
}

void testStatement(String message, String code) {
  test(message, () {
    addFile('''
void main() {
  $code
}
''');
    check();
  });
}