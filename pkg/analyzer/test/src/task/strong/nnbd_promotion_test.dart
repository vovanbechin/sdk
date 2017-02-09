// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Hacky tests for the prototype implementation of non-nullable types. Unlike
// non_null_checker_test.dart, these are the newer ones that test *all* types
// supporting non-nullability.

import 'package:test/test.dart';

import '../strong/strong_test_helper.dart';
import 'util.dart';

void main() {
  setUp(doSetUp);
  tearDown(doTearDown);

  // We don't test every combination of expressions that promote ("is", etc.)
  // and syntax that contains promotion ("if", "&&", etc.). Instead, we try to
  // cover one of each in some combination and assume the general type
  // promotion tests have us covered.

  // TODO(nnbd): Consider extending type promotion to cover negative cases in
  // else:
  //
  //    String s?;
  //    if (s == null) {
  //      ...
  //    } else {
  //      <promote s to String here>
  //    }

  // TODO(nnbd): Consider extending type promotion to cover abrupt exits:
  //
  //    String? s;
  //    if (s == null) return;
  //    <promote s to String here>

  group("==/!= null", () {
    testStatements("nullable type == null", """
      String? s;
      if (s == null) {
        // Promote to Null.
        s.toString();
        s?./*error:UNDEFINED_GETTER*/length;
      }
      """);

    testStatements("nullable type != null", """
      String? s;
      if (s != null) {
        s.length;
      }
      """);

    testStatements("!= null and &&", """
      String? s;
      s != null && s.length == 0;
      """);

    testUnit("does nothing if LHS is not a local variable", """
      String? s;
      main() {
        if (s != null) {
          s./*error:UNDEFINED_GETTER*/length;
        }
      }
      """);
  });

  group("is", () {
    testStatements("nullable to non-nullable", """
      String? s;
      if (s is String) s.length;
      """);

    testStatements("Object to nullable", """
      Object s;
      if (s is String?) s?.length;
      """);

    testStatements("dynamic to nullable", """
      dynamic s;
      if (s is String?) {
        s?.length;
        s?./*error:UNDEFINED_GETTER*/nope;
      }
      """);

    testStatements("non-nullable to nullable does not promote", """
      String s = "";
      if (s is String?) s.length;
      """);

    testStatements("non-nullable to nullable does not promote", """
      String s = "";
      if (s is String?) s.length;
      """);

    testStatements("nullable to Null", """
      String? s;
      if (s is Null) {
        s.toString();
        s?./*error:UNDEFINED_GETTER*/length;
      }
      """);
  });

  group("&&", () {
    testStatements("nullable to non-nullable", """
      String? s;
      s is String && s.length == 0;
      """);

    testStatements("nullable to Null", """
      String? s;
      s is Null && s?./*error:UNDEFINED_GETTER*/length == 0;
      """);
  });
}
