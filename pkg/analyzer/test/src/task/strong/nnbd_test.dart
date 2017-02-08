// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Hacky tests for the prototype implementation of non-nullable types. Unlike
// non_null_checker_test.dart, these are the newer ones that test *all* types
// supporting non-nullability.

import 'package:test/test.dart';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/src/error/codes.dart';

import '../strong/strong_test_helper.dart';

void main() {
  setUp(doSetUp);
  tearDown(doTearDown);

  group("initialized local", () {
    testStatements(
        "non-nullable with null", 'int i = /*error:INVALID_ASSIGNMENT*/null;');

    testStatements("Object with null", 'Object i = null;');

    testStatements("Null with null", 'Null i = null;');

    testStatements(
        "Null with other type", 'Null i = /*error:INVALID_ASSIGNMENT*/123;');

    testStatements("nullable with null", "int? i = null;");

    testStatements("nullable with value", "int? i = 123;");

    testStatements("nullable with other type",
        "int? i = /*error:INVALID_ASSIGNMENT*/123.4;");

    testStatements("non-nullable with nullable",
        "int i = /*error:INVALID_ASSIGNMENT*/(123 as int?);");
  });

  group("uninitialized local", () {
    // TODO(rnystrom): Better error message.
    testStatements(
        "non-nullable", 'int /*error:NON_NULLABLE_FIELD_NOT_INITIALIZED*/i;');

    testStatements("untyped", 'var i;');

    testStatements("object", 'Object i;');

    testStatements("dynamic", 'dynamic i;');

    testStatements("nullable", "int? i;");
  });

  group("field", () {
    testMembers(
        "non-nullable", 'int /*error:NON_NULLABLE_FIELD_NOT_INITIALIZED*/i;');

    testMembers("untyped", 'var i;');

    testMembers("Object", 'Object i;');

    testMembers("dynamic", 'dynamic i;');

    testMembers("nullable", 'int? i;');

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
    testStatements("null to non-nullable",
        "int i = 1; i = /*error:INVALID_ASSIGNMENT*/null;");

    testStatements("null to Object", "Object i = 1; i = null;");

    testStatements("null to dynamic", "dynamic i = 1; i = null;");

    testStatements("null to inferred non-nullable",
        "var i = 1; i = /*error:INVALID_ASSIGNMENT*/null;");

    testStatements("value to nullable", "int? i = 1; i = 2;");

    testStatements("null to nullable", "int? i = 1; i = null;");

    testStatements("wrong type to nullable",
        "int? i = 1; i = /*error:INVALID_ASSIGNMENT*/2.4;");

    testUnit(
        "null to type parameter",
        '''class Foo<T> {
          bar() {
            T t = /*error:INVALID_ASSIGNMENT*/null;
          }
        }''');

    testUnit(
        "null to nullable type parameter",
        '''class Foo<T> {
          bar() {
            T? t = null;
          }
        }''');

    testUnit(
        "nullable type parameter to type parameter",
        '''class Foo<T> {
          bar(T? p) {
            T t = /*error:INVALID_ASSIGNMENT*/p;
          }
        }''');

    testUnit(
        "type parameter to nullable type parameter",
        '''class Foo<T> {
          bar(T p) {
            T? t = p;
          }
        }''');
  });

  group("argument", () {
    // We don't test all of the various cases of argument binding because we
    // assume the same rules for assignment are in play. Just test one or two
    // to validate that assumption.

    testUnit(
        "nullable to non-nullable",
        """
      foo(int i, [int j = 0]) {}
      named({int i = 0}) {}
      main() {
        int? i = 123;
        foo(/*error:ARGUMENT_TYPE_NOT_ASSIGNABLE*/i,
            /*error:ARGUMENT_TYPE_NOT_ASSIGNABLE*/i);
        named(/*error:ARGUMENT_TYPE_NOT_ASSIGNABLE*/i: i);
      }
      """);
  });

  group("subtype", () {
    testEquivalentTypes("int?", "int?");
    testEquivalentTypes("Object?", "Object");

    testMoreSpecific("int", "int?");
    testMoreSpecific("Null", "int?");
    testMoreSpecific("int?", "num?");
    testMoreSpecific("int?", "Object");

    testMoreSpecific("int", "num?");
    testMoreSpecific("int?", "num?");
    testNotSubtype("int?", "num");

    // Unrelated types.
    testNotSubtype("String?", "num?");
  });

  testUnit(
      "repeated nullables flatten",
      """
  class Nullify<T> {
    T? field;
  }

  main() {
    int? i = new Nullify<int>().field;
    int? j = new Nullify<int?>().field;
  }
  """);

  group("optional parameters", () {
    group("non-nullable", () {
      testUnit(
          "without default",
          """
          pos([/*error:NON_NULLABLE_PARAMETER_WITHOUT_DEFAULT*/int param]) {}
          named({/*error:NON_NULLABLE_PARAMETER_WITHOUT_DEFAULT*/int param}) {}
          """);

      testUnit(
          "with null default",
          """
          pos([int param = /*error:INVALID_ASSIGNMENT*/null]) {}
          named({int param = /*error:INVALID_ASSIGNMENT*/null}) {}
          """);

      testUnit(
          "with valid default",
          """
          pos([int param = 123]) {}
          named({int param = 123}) {}
          """);
    });

    group("nullable", () {
      testUnit(
          "without default",
          """
          pos([int? param]) {}
          named({int? param}) {}
          """);

      testUnit(
          "with null default",
          """
          pos([int? param = null]) {}
          named({int? param = null}) {}
          """);

      testUnit(
          "with valid default",
          """
          pos([int? param = 123]) {}
          named({int? param = 123}) {}
          """);

      testUnit(
          "function type",
          """
          pos([int param()?]) {}
          named({int param()?}) {}
          """);
    });

    group("Object", () {
      testUnit(
          "without default",
          """
          pos([Object param]) {}
          named({Object param}) {}
          """);

      testUnit(
          "with null default",
          """
          pos([Object param = null]) {}
          named({Object param = null}) {}
          """);

      testUnit(
          "with valid default",
          """
          pos([Object param = 123]) {}
          named({Object param = 123}) {}
          """);
    });

    group("dynamic", () {
      testUnit(
          "without default",
          """
          pos([dynamic param]) {}
          named({param}) {}
          """);

      testUnit(
          "with null default",
          """
          pos([param = null]) {}
          named({dynamic param = null}) {}
          """);

      testUnit(
          "with valid default",
          """
          pos([dynamic param = 123]) {}
          named({param = 123}) {}
          """);
    });

    group("declaration kinds", () {
      testUnit(
          "method",
          """
      class Foo {
        pos([/*error:NON_NULLABLE_PARAMETER_WITHOUT_DEFAULT*/int param]) {}
        named({/*error:NON_NULLABLE_PARAMETER_WITHOUT_DEFAULT*/int param}) {}
      }
      """);

      testUnit(
          "top-level function",
          """
      pos([/*error:NON_NULLABLE_PARAMETER_WITHOUT_DEFAULT*/int param]) {}
      named({/*error:NON_NULLABLE_PARAMETER_WITHOUT_DEFAULT*/int param}) {}
      """);

      testUnit(
          "local function",
          """
      main() {
        pos([/*error:NON_NULLABLE_PARAMETER_WITHOUT_DEFAULT*/int param]) {}
        named({/*error:NON_NULLABLE_PARAMETER_WITHOUT_DEFAULT*/int param}) {}
      }
      """);

      testUnit(
          "lambda",
          """
      main() {
        var p = ([/*error:NON_NULLABLE_PARAMETER_WITHOUT_DEFAULT*/int p]) {};
        var n = ({/*error:NON_NULLABLE_PARAMETER_WITHOUT_DEFAULT*/int p}) {};
      }
      """);
    });

    // TODO(nnbd): If we make passing an explicit null substitute the default
    // value, then this does not need to be an error.
    testUnit(
        "pass explicit null for optional",
        """
      pos([int param = 1]) {}
      named({int param = 1}) {}
      main() {
        pos(/*error:ARGUMENT_TYPE_NOT_ASSIGNABLE*/null);
        named(/*error:ARGUMENT_TYPE_NOT_ASSIGNABLE*/param: null);
      }
      """);

    group("generic methods", () {
      testUnit(
          "without default",
          """
          foo<T>([/*error:NON_NULLABLE_PARAMETER_WITHOUT_DEFAULT*/T t]) {}
          """);

      testUnit(
          "nullable without default",
          """
          foo<T>([T? t]) {}
          """);
    });

    group("lub", () {
      group("ternary", () {
        testHasType("b ? 123 : 12.34", "num");

        // Ternary with null.
        testHasType("b ? null : null", "Null");
        testHasType("b ? 123 : null", "int?");
        testHasType("b ? 's' : null", "String?");
        testHasType("b ? (123 as int?) : null", "int?");

        // Ternary with nullable.
        testHasType("b ? (1 as int?) : (1 as int?)", "int?");
        testHasType("b ? (1 as int?) : (1.2 as num?)", "num?");
        testHasType("b ? (1 as int?) : (1.2 as double?)", "num?");
        testHasType("b ? (1 as int?) : ('s' as String?)", "Object");
        testHasType("b ? (1 as int?) : 's'", "Object");
      });

      group("lists", () {
        testHasType("[null, null]", "List<Null>");
        testHasType("[1, null]", "List<int?>");
        testHasType("[1, null, 2.0]", "List<num?>");
        testHasType("[1, null, 'str']", "List<Object>");
        testHasType("[[null], [1]]", "List<List<int?>>");
        // TODO(nnbd): Could provide a better type if we infer Null for empty
        // lists.
        testHasType("[[], [1]]", "List<List<dynamic>>");
      });

      group("maps", () {
        testHasType("{'a': null, 'b': null}", "Map<String, Null>");
        testHasType("{'a': 1, 'b': null}", "Map<String, int?>");
        testHasType("{'a': 1, 'b': null, 'c': 2.0}", "Map<String, num?>");
        testHasType("{'a': 1, 'b': null, 'c': 'str'}", "Map<String, Object>");
        testHasType("{'a': [null], 'b': [1]}", "Map<String, List<int?>>");
        // TODO(nnbd): Could provide a better type if we infer Null for empty
        // maps.
        testHasType("{'a': {}, 'b': {1: 1}}", "Map<String, Map<dynamic, dynamic>>");
      });

      // TODO(nnbd): More complex tests with function types and generics.
    });
  });
}

void testHasType(String expression, String type, {String context}) {
  if (context == null) context = "";

  test("`$expression` has type $type", () {
    addFile("""
        main() {
          bool b = true;
          $context
          var f = $expression;
        }
        """);

    var unit = check(ignoredErrors: [StrongModeCode.INFERRED_TYPE_LITERAL]);
    var main = unit.declarations[0] as FunctionDeclaration;
    var body = main.functionExpression.body as BlockFunctionBody;
    var f = body.block.statements.last as VariableDeclarationStatement;
    var variable = f.variables.variables.first.element;
    expect(variable.type.toString(), type);
  });
}

void testMoreSpecific(String t1, String t2) {
  expectSubtype(t1, t2);
  testNotSubtype(t2, t1);
}

void testEquivalentTypes(String t1, String t2) {
  expectSubtype(t1, t2);
  expectSubtype(t2, t1);
}

void expectSubtype(String t1, String t2) {
  // TODO(bob): Hokey. Using covariant return type and assuming that strong mode
  // uses regular subtype rules for override (instead of assignability). Could
  // test this more directly, but this works.
  testUnit(
      "$t1 should be a subtype of $t2",
      """
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
  testUnit(
      "$t1 should not be a subtype of $t2",
      """
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
