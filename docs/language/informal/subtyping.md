# Dart 2.0 static and runtime subtyping

leafp@google.com

Status: Draft

This is intended to define the core of the Dart 2.0 static and runtime subtyping
relation.

## Types

The syntactic set of types used in this draft are a slight simplification of
full Dart types.

The meta-variables `X`, `Y`, and `Z` range over type variables.

The meta-variables `T`, `S`, and `U` range over types.

The meta-variable `C` ranges over classes.

The meta-variable `B` ranges over types used as bounds for type variables.

The set of types under consideration are as follows:

- Type variables `X` 
- Promoted type variables `X & T` *Note: static only*
- `Object`
- `dyamic`
- `void`
- `Null`
- `Function`
- `Future<T>`
- `FutureOr<T>`
- Interface types `C`, `C<T0, ..., Tn>`
- Function types
  - `U <X0 extends B0, ...., Xn extends Bn>(T0 x0, ...., Tn xn, [Tn+1 xn+1, ..., Tm xm])`
  - `U <X0 extends B0, ...., Xn extends Bn>(T0 x0, ...., Tn xn, {Tn+1 xn+1, ..., Tm xm})`

We leave the set of interface types unspecified, but assume a class hierarchy
which provides a mapping from interfaces types `M` to their super class type, to
a set of directly implemented interfaces, and to a set of directly applied
mixins.  Among other well-formedness constraints, the edges induced by this
mapping must form a directed acyclic graph rooted at `Object`.

The types `Object`, `dynamic` and `void` are all referred to as *top* types, and
are considered equivalent as types.  They exist as distinct names only to
support distinct errors and warnings.

Promoted type variables only occur statically (never at runtime).

Given the current promotion semantics the following properties are also true:
   - If `X` has bound `B` then for any type `X & T`, `T <: B` will be true
   - Promoted type variable types will only appear as top level types: that is, 
     they can never appear as sub-components of other types, in bounds, or as 
     part of other promoted type variables.

## Notation

We use `S[T0/Y0, ..., Tl/Yl]` for the result of performing a simultaneous
capture-avoiding substituion of types `T0, ..., Tl` for the type variables `Y0,
..., Yl` in the type `S`.

## Type equality

We say that a type `T0` is equal to another type `T1` (written `T0 === T1`) if
the two types are structurally equal up to renaming of bound type variables,
and equating all top types.

TODO: make these rules explicit.

## Subtyping

We say that a type `T0` is a subtype of a type `T1` (written `T0 <: T1`) when:

`T0` and `T1` are the same type.
 - *Note that this check is necessary as the base case for primitive types, and
   type variables but not for composite type.  In particular, algorithmically a
   structural equality check is admissible, but not required here*

`T1` is a top type (i.e. `Object`, `dynamic`, or `void`).

`T0` is `Null`

`T0` is `FutureOr<S0>` and `T1` is `FutureOr<S1>` and `S0 <: S1`

`T0` is `FutureOr<S0>` and `Future<S0> <: T1` and `S0 <: T1`

`T0` is not `FutureOr<S0>` and `T1` is `FutureOr<S1`> and
  - `T0 <: Future<S1>` or `T0 <: S1`

`T0` is a type variable `X0` 
  - and `T1` is neither `X0` nor `X0 & S1`
  - and `X0` has bound `B0`
  - and `B0 <: T1`

`T0` is a type variable `X0` 
  - and `T1` is `X0 & S1`
  - and `T0` has bound `B0`
  - and `B0 <: S1`
  - *Note: By current promotion rules, the last premise is always true*

`T0` is a promoted type variable `X0 & S0` 
  - and `T1` is neither `X0` nor `X0 & S1`
  - and either `X0 <: T1` or `S0 <: T1`

`T1` is a promoted type variable `X1 & S1` 
  - and `T0` is neither `X1` nor `X1 & S0`
  - and `T0 <: X1`
  - and `T0 <: S0`

*Note: I think these last two rules are more declarative than necessary, and
could be made more algorithmic avoiding some backtracking.*

`T0` is a function type and `T1` is `Function`

`T0` is an interface type with class `C0` and `T1` is a function type or `Function`
  - and `T0` has a call method with signature `S0`
  - and `S0 <: T1` without re-expanding the call method from `C0` again
  - *Note: the wording about re-expanding the call method is a 
    workaround for https://github.com/dart-lang/sdk/issues/29791*

`T0` is an interface type `C0` and `T` is `C0`.

`T0` is an interface type `C0<S0, ..., Sn>`
  - and `T1` is an interface type `C0<U0, ..., Un>`
  - and each `Si <: Ui`

`T0` has superclass `S0` and `S0 <: T1`

`T0` has super-interfaces `S0, ...Sn`
  - and `Si <: T1` for some `i`

`T0` has mixin-interfaces `S0, ...Sn`
  - and `Si <: T1` for some `i`

`T0` is `U0 <X0 extends B00, ..., Xl extends B0l>(T0 x0, ..., Tn xn, [Tn+1 xn+1, ..., Tm xm])`
  - and `T1` is `U1 <Y0 extends B10, ..., Yl extends B1l>(S0 y0, ..., Sn yp, [Sp+1 yp+1, ..., Sq yq])`
  - and `p >= n`
  - and `m >= q`
  - and `Si[Z0/Y0, ..., Zl/Yl] <: Ti[Z0/X0, ..., Zl/Xl]` for `i` in `0...q`
  - and `U0[Z0/X0, ..., Zl/Xl] <: U1[Z0/Y0, ..., Zl/Yl]`
  - and `B0i[Z0/X0, ..., Zl/Xl] === B1i[Z0/Y0, ..., Zl/Yl]` for `i` in `0...l`
  - where the `Zi` are fresh type variables with bounds `B0i[Z0/X0, ..., Zl/Xl]`
  
`T0` is `U0 <X0 extends B00, ..., Xl extends B0l>(T0 x0, ..., Tn xn, {Tn+1 xn+1, ..., Tm xm})`
  - and `T1` is `U1 <Y0 extends B10, ..., Yl extends B1l>(S0 y0, ..., Sn yn, [Sn+1 yn+1, ..., Sq yq])`
  - and `m >= q`
  - and `Si[Z0/Y0, ..., Zl/Yl] <: Ti[Z0/X0, ..., Zl/Xl]` for `i` in `0...n`
  - and `Si[Z0/Y0, ..., Zl/Yl] <: Tj[Z0/X0, ..., Zl/Xl]` for `i` in `0...q`, `yj = xi`
  - and `U0[Z0/X0, ..., Zl/Xl] <: U1[Z0/Y0, ..., Zl/Yl]`
  - and `B0i[Z0/X0, ..., Zl/Xl] === B1i[Z0/Y0, ..., Zl/Yl]` for `i` in `0...l`
  - where the `Zi` are fresh type variables with bounds `B0i[Z0/X0, ..., Zl/Xl]`

*Note: the requirement that `Zi` are fresh is as usual strictly a requirement
that the choice of common variable names avoid capture.  It is valid to choose
the `Xi` or the `Yi` for `Zi` so long as capture is avoided*

