// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library touch_event_test;
import 'package:unittest/unittest.dart';
import 'package:unittest/html_individual_config.dart';
import 'dart:html';

main() {
  useHtmlIndividualConfiguration();

  group('supported', () {
    test('supported', () {
      expect(TouchEvent.supported, true);
    });
  });

  group('functional', () {
    test('TouchEvent construction', () {
      var e = new TouchEvent('touch');
      expect(e is TouchEvent, true);

      var e2 = new TouchEvent("touch", { 'touches': [], 'targetTouches': [], 'changedTouches': [] } );
      expect(e2 is TouchEvent, true);
    });
  });
}
