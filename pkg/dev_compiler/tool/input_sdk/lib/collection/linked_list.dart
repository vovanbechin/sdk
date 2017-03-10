// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of dart.collection;


/**
 * A specialized double-linked list of elements that extends [LinkedListEntry].
 *
 * This is not a generic data structure. It only accepts elements that extend
 * the [LinkedListEntry] class. See the [Queue] implementations for
 * generic collections that allow constant time adding and removing at the ends.
 *
 * This is not a [List] implementation. Despite its name, this class does not
 * implement the [List] interface. It does not allow constant time lookup by
 * index.
 *
 * Because the elements themselves contain the links of this linked list,
 * each element can be in only one list at a time. To add an element to another
 * list, it must first be removed from its current list (if any).
 *
 * In return, each element knows its own place in the linked list, as well as
 * which list it is in. This allows constant time [LinkedListEntry.addAfter],
 * [LinkedListEntry.addBefore] and [LinkedListEntry.unlink] operations
 * when all you have is the element.
 *
 * A `LinkedList` also allows constant time adding and removing at either end,
 * and a constant time length getter.
 */
class LinkedList<E extends LinkedListEntry<E>>
    extends Iterable<E> {

  int _modificationCount = 0;
  int _length = 0;
  E? _first;

  /**
   * Construct a new empty linked list.
   */
  LinkedList();

  /**
   * Add [entry] to the beginning of the linked list.
   */
  void addFirst(E entry) {
    _insertBefore(_first, entry, updateFirst: true);
    _first = entry;
  }

  /**
   * Add [entry] to the end of the linked list.
   */
  void add(E entry) {
    _insertBefore(_first, entry, updateFirst: false);
  }

  /**
   * Add [entries] to the end of the linked list.
   */
  void addAll(Iterable<E> entries) {
    entries.forEach(add);
  }

  /**
   * Remove [entry] from the linked list.
   *
   * Returns false and does nothing if [entry] is not in this linked list.
   *
   * This is equivalent to calling `entry.unlink()` if the entry is in this
   * list.
   */
  bool remove(E entry) {
    if (entry._list != this) return false;
    _unlink(entry);  // Unlink will decrement length.
    return true;
  }

  Iterator<E> get iterator => new _LinkedListIterator<E>(this);

  int get length => _length;

  /**
   * Remove all elements from this linked list.
   */
  void clear() {
    _modificationCount++;
    if (isEmpty) return;

    // TODO(nnbd-assert): This is implied by the above isEmpty, but the type
    // system doesn't know that.
    E next = _first as E;
    do {
      E entry = next;
      // TODO(nnbd-assert): If the list isn't empty, all of the nodes have
      // valid links.
      next = entry._next as E;
      entry._next = entry._previous = entry._list = null;
    } while (!identical(next, _first));

    _first = null;
    _length = 0;
  }

  E get first {
    // TODO(nnbd-throw): Using a clever little pattern here. Not sure if it's a good
    // one or not, but it works.
    // if (isEmpty) {
    //   throw new StateError('No such element');
    // }
    // return _first;
    return _first ?? (throw new StateError('No such element'));
  }

  E get last {
    // TODO(nnbd-throw): Using a clever little pattern here. Not sure if it's a good
    // one or not, but it works.
    // if (isEmpty) {
    //   throw new StateError('No such element');
    // }
    // return _first._previous;
    return _first?._previous ?? (throw new StateError('No such element'));
  }

  E get single {
    if (_length > 1) {
      throw new StateError('Too many elements');
    }
    // TODO(nnbd-throw): Using a clever little pattern here. Not sure if it's a good
    // one or not, but it works.
    // if (isEmpty) {
    //   throw new StateError('No such element');
    // }
    return _first ?? (throw new StateError('No such element'));
  }

  /**
   * Call [action] with each entry in this linked list.
   *
   * It's an error if [action] modify the linked list.
   */
  void forEach(void action(E entry)) {
    int modificationCount = _modificationCount;
    if (isEmpty) return;

    // TODO(nnbd-assert): Implied by about isEmpty check.
    E current = _first as E;
    do {
      action(current);
      if (modificationCount != _modificationCount) {
        throw new ConcurrentModificationError(this);
      }
      // TODO(nnbd-assert)
      current = current._next as E;
    } while (!identical(current, _first));
  }

  bool get isEmpty => _length == 0;

  /// Inserts [newEntry] as last entry of the list.
  ///
  /// If [updateFirst] is true and [entry] is the first entry in the list,
  /// updates the [_first] field to point to the [newEntry] as first entry.
  // TODO(nnbd-required-named): updateFirst is treated like a required
  // parameter and is always passed.
  void _insertBefore(E? entry, E newEntry, {bool? updateFirst}) {
    if (newEntry.list != null) {
      throw new StateError(
          'LinkedListEntry is already in a LinkedList');
    }
    _modificationCount++;

    newEntry._list = this;
    if (isEmpty) {
      assert(entry == null);
      newEntry._previous = newEntry._next = newEntry;
      _first = newEntry;
      _length++;
      return;
    }
    // TODO(nnbd): This method is a little ugly with non-nullable types.
    // It should probably be reorganized to be more null-safe.
    E predecessor = (entry as E)._previous as E;
    E successor = (entry as E);
    newEntry._previous = predecessor;
    newEntry._next = successor;
    predecessor._next = newEntry;
    successor._previous = newEntry;
    if ((updateFirst as bool) && identical(entry, _first)) {
      _first = newEntry;
    }
    _length++;
  }

  void _unlink(E entry) {
    _modificationCount++;
    // TODO(nnbd-assert)
    (entry._next as E)._previous = entry._previous;
    var next = (entry._previous as E)._next = entry._next;
    _length--;
    entry._list = entry._next = entry._previous = null;
    if (isEmpty) {
      _first = null;
    } else if (identical(entry, _first)) {
      _first = next;
    }
  }
}


class _LinkedListIterator<E extends LinkedListEntry<E>>
    implements Iterator<E> {
  final LinkedList<E> _list;
  final int _modificationCount;
  E? _current;
  LinkedListEntry<E>? _next;
  bool _visitedFirst;

  _LinkedListIterator(LinkedList<E> list)
    : _list = list,
      _modificationCount = list._modificationCount,
      _next = list._first,
      _visitedFirst = false;

  E get current => _current as E;

  bool moveNext() {
    if (_modificationCount != _list._modificationCount) {
      throw new ConcurrentModificationError(this);
    }
    if (_list.isEmpty ||
        (_visitedFirst && identical(_next, _list.first))) {
      _current = null;
      return false;
    }
    _visitedFirst = true;
    _current = _next;
    // TODO(nnbd-assert)
    _next = (_next as E)._next;
    return true;
  }
}


/**
 * An object that can be an element in a [LinkedList].
 *
 * All elements of a `LinkedList` must extend this class.
 * The class provides the internal links that link elements together
 * in the `LinkedList`, and a reference to the linked list itself
 * that an element is currently part of.
 *
 * An entry can be in at most one linked list at a time.
 * While an entry is in a linked list, the [list] property points to that
 * linked list, and otherwise the `list` property is `null`.
 *
 * When created, an entry is not in any linked list.
 */
abstract class LinkedListEntry<E extends LinkedListEntry<E>> {
  LinkedList<E>? _list;
  E? _next;
  E? _previous;

  /**
   * Get the linked list containing this element.
   *
   * Returns `null` if this entry is not currently in any list.
   */
  LinkedList<E>? get list => _list;

  /**
   * Unlink the element from its linked list.
   *
   * The entry must currently be in a linked list when this method is called.
   */
  void unlink() {
    // TODO(nnbd-assert): Note doc comment.
    (_list as LinkedList<E>)._unlink(this);
  }

  /**
   * Return the succeessor of this element in its linked list.
   *
   * Returns `null` if there is no successor in the linked list, or if this
   * entry is not currently in any list.
   */
  E? get next {
    if (identical(this, _next)) return null;
    return _next;
  }

  /**
   * Return the predecessor of this element in its linked list.
   *
   * Returns `null` if there is no predecessor in the linked list, or if this
   * entry is not currently in any list.
   */
  E? get previous {
    if (identical(this, _previous)) return null;
    return _previous;
  }

  /**
   * Insert an element after this element in this element's linked list.
   *
   * This entry must be in a linked list when this method is called.
   * The [entry] must not be in a linked list.
   */
  void insertAfter(E entry) {
    // TODO(nnbd-assert): Note doc comment.
    (_list as LinkedList<E>)._insertBefore(_next, entry, updateFirst: false);
  }

  /**
   * Insert an element before this element in this element's linked list.
   *
   * This entry must be in a linked list when this method is called.
   * The [entry] must not be in a linked list.
   */
  void insertBefore(E entry) {
    // TODO(nnbd-assert): Note doc comment.
    (_list as LinkedList<E>)._insertBefore(this as dynamic/*=E*/, entry, updateFirst: true);
  }
}
