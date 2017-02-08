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

  group("methods", () {
    testStatements("has Object methods", """
        int? i;
        i == i;
        i.toString();
        i.hashCode;
        i.runtimeType;
        """);

    testStatements("does not have base type methods", """
        int? i;
        i./*error:UNDEFINED_METHOD*/toInt();
        i /*error:UNDEFINED_OPERATOR*/+ 1;
        i./*error:UNDEFINED_GETTER*/isEven;
        """);

    // For setters and functions, we need some more setup.
    testUnit("does not have base type methods", """
        typedef void Callback();

        class Foo {
          Object settable;
        }

        main() {
          Foo? f;
          f./*error:UNDEFINED_SETTER*/settable = 123;

          Callback? c;
          // TODO(nnbd): Use a more specific error message in a real implementation.
          /*error:INVOCATION_OF_NON_FUNCTION*/c();
        }
        """);
  });

  group("conditions", () {
    testStatements("do", """
        bool? b;
        do {} while (/*error:NON_BOOL_CONDITION*/b);
        """);

    testStatements("for", """
        bool? b;
        for (;/*error:NON_BOOL_CONDITION*/b;) {}
        """);

    testStatements("if", """
        bool? b;
        if (/*error:NON_BOOL_CONDITION*/b) {}
        """);

    testStatements("while", """
        bool? b;
        while (/*error:NON_BOOL_CONDITION*/b) {}
        """);

    testStatements("ternary", """
        bool? b;
        /*error:NON_BOOL_CONDITION*/b ? 1 : 2;
        """);
  });

  group("null-aware", () {
    testStatements("property", """
      String? s;
      s?.length;
      """);

    testStatements("method", """
      int? i;
      i?.toInt();
      """);

    testUnit("setter", """
      class Foo {
        int bar = 1;
      }

      main() {
        Foo? foo;
        foo?.bar = 123;
      }
      """);
  });
}
