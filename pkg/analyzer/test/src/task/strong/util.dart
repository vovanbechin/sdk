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
  testUnit(
      message,
      '''
void main() {
  $code
}
''');
}

void testMembers(String message, String code) {
  testUnit(
      message,
      '''
class Foo {
  $code
}
''');
}

void testUnit(String message, String code) {
  test(message, () {
    addFile(code);
    check(ignoreUndefinedMethod: false, ignoredErrors: [
      StrongModeCode.DYNAMIC_INVOKE,
      HintCode.TYPE_CHECK_IS_NULL,
      HintCode.TYPE_CHECK_IS_NOT_NULL
    ]);
  });
}
