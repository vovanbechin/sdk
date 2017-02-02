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

    testStatements(
        "nullable with null",
        "int? i = null;");

    testStatements(
        "nullable with value",
        "int? i = 123;");

    testStatements(
        "nullable with other type",
        "int? i = /*error:INVALID_ASSIGNMENT*/123.4;");

    testStatements(
        "non-nullable with nullable",
        "int i = /*error:INVALID_ASSIGNMENT*/(123 as int?);");
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
        "object",
        'Object i;');

    testStatements(
        "dynamic",
        'dynamic i;');

    testStatements(
        "nullable",
        "int? i;");
  });

  group("field", () {
    testMembers(
        "non-nullable",
        'int /*error:NON_NULLABLE_FIELD_NOT_INITIALIZED*/i;');

    testMembers(
        "untyped",
        'var i;');

    testMembers(
        "Object",
        'Object i;');

    testMembers(
        "dynamic",
        'dynamic i;');

    testMembers(
        "nullable",
        'int? i;');

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

    testUnit(
        "uninitialized nullable type parameter",
        '''class Foo<T> {
          T? t;
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

    testStatements(
        "value to nullable",
        "int? i = 1; i = 2;");

    testStatements(
        "null to nullable",
        "int? i = 1; i = null;");

    testStatements(
        "wrong type to nullable",
        "int? i = 1; i = /*error:INVALID_ASSIGNMENT*/2.4;");
  });

  group("subtype", () {
    testEquivalent("int?", "int?");
    testEquivalent("Object?", "Object");

    testMoreSpecific("int", "int?");
    testMoreSpecific("Null", "int?");
    testMoreSpecific("int?", "num?");
    testMoreSpecific("int?", "Object");

    // Unrelated types.
    testNotSubtype("String?", "num?");
  });

  testUnit("repeated nullables flatten", """
  class Nullify<T> {
    T? field;
  }

  main() {
    int? i = new Nullify<int>().field;
    int? j = new Nullify<int?>().field;
  }
  """);


  // TODO: variable of nullable type parameter type when instantiated with
  // nullable type argument.
}

void testMoreSpecific(String t1, String t2) {
  testSubtype(t1, t2);
  testNotSubtype(t2, t1);
}

void testEquivalent(String t1, String t2) {
  testSubtype(t1, t2);
  testSubtype(t2, t1);
}

void testSubtype(String t1, String t2) {
  // TODO(bob): Hokey. Using covariant return type and assuming that strong mode
  // uses regular subtype rules for override (instead of assignability). Could
  // test this more directly, but this works.
  testUnit("$t1 should be a subtype of $t2", """
abstract class A {
  $t2 method();
}

abstract class B extends A {
  $t1 method();
}
""");
}

void testNotSubtype(String t1, String t2) {
  // TODO(bob): Hokey. Using covariant return type and assuming that strong mode
  // uses regular subtype rules for override (instead of assignability). Could
  // test this more directly, but this works.
  testUnit("$t1 should not be a subtype of $t2", """
abstract class A {
  $t2 method();
}

abstract class B extends A {
  /*error:INVALID_METHOD_OVERRIDE*/$t1 method();
}
""");
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