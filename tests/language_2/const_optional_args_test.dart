// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Check that const objects (including literals) are immutable.

// Must be 'const {}' to be valid.
invalid(
    [var p =
    /* //# 01: compile-time error
    const
    */ //# 01: continued
    {}]) {}

main() {
  invalid();
}
