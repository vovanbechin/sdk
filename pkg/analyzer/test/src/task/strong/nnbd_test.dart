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

  group("initialized local", () {
    testStatements(
        "non-nullable with null",
        'int i = /*error:INVALID_ASSIGNMENT*/null;');

    testStatements(
        "Object with null",
        'Object i = null;');

    testStatements(
        "Null with null",
        'Null i = null;');

    testStatements(
        "Null with other type",
        'Null i = /*error:INVALID_ASSIGNMENT*/123;');
  });

  group("uninitialized local", () {
    // TODO(rnystrom): Better error message.
    testStatements(
        "non-nullable",
        'int /*error:NON_NULLABLE_FIELD_NOT_INITIALIZED*/i;');

    testStatements(
        "untyped",
        'var i;');

    testStatements(
        "nullable",
        'Object i;');

    testStatements(
        "dynamic",
        'dynamic i;');
  });

  group("field", () {
    testMembers(
        "non-nullable",
        'int /*error:NON_NULLABLE_FIELD_NOT_INITIALIZED*/i;');

    testMembers(
        "untyped",
        'var i;');

    testMembers(
        "nullable",
        'Object i;');

    testMembers(
        "dynamic",
        'dynamic i;');

    testUnit(
        "initialized with initializing formal",
        '''class Foo {
          int i;
          Foo(this.i);
        }''');

    testUnit(
        "initialized in initialization list",
        '''class Foo {
          int i;
          Foo() : i = 0;
        }''');

    testUnit(
        "not initialized in all ctors",
        '''class Foo {
          int i;
          Foo() : i = 0;
          Foo.good() : i = 0;
          /*error:NON_NULLABLE_FIELD_NOT_INITIALIZED*/Foo.bad();
        }''');

    testUnit(
        "not initialized inherited field type",
        '''
        class A {
          int get i => 1;
        }

        class B implements A {
          var /*error:NON_NULLABLE_FIELD_NOT_INITIALIZED*/i;
        }''');

    testUnit(
        "uninitialized type parameter",
        '''class Foo<T> {
          T /*error:NON_NULLABLE_FIELD_NOT_INITIALIZED*/t;
        }''');
  });

  group("assignment", () {
    testStatements(
        "null to non-nullable",
        "int i = 1; i = /*error:INVALID_ASSIGNMENT*/null;");

    testStatements(
        "null to Object",
        "Object i = 1; i = null;");

    testStatements(
        "null to dynamic",
        "dynamic i = 1; i = null;");

    testStatements(
        "null to inferred non-nullable",
        "var i = 1; i = /*error:INVALID_ASSIGNMENT*/null;");
    // TODO: null to nullable type.
  });
}

void testStatements(String message, String code) {
  test(message, () {
    addFile('''
void main() {
  $code
}
''');
    check();
  });
}

void testMembers(String message, String code) {
  test(message, () {
    addFile('''
class Foo {
  $code
}
''');
    check();
  });
}

void testUnit(String message, String code) {
  test(message, () {
    addFile(code);
    check();
  });
}