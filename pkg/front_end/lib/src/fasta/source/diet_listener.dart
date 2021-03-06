// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library fasta.diet_listener;

import 'package:kernel/ast.dart'
    show
        AsyncMarker,
        Expression,
        InterfaceType,
        Library,
        LibraryDependency,
        LibraryPart,
        Node,
        TreeNode,
        VariableDeclaration;

import 'package:kernel/class_hierarchy.dart' show ClassHierarchy;

import 'package:kernel/core_types.dart' show CoreTypes;

import '../../scanner/token.dart' show Token;

import '../builder/builder.dart';

import '../constant_context.dart' show ConstantContext;

import '../crash.dart' show Crash;

import '../deprecated_problems.dart'
    show deprecated_InputError, deprecated_inputError;

import '../fasta_codes.dart'
    show Message, messageExpectedBlockToSkip, templateInternalProblemNotFound;

import '../kernel/kernel_body_builder.dart' show KernelBodyBuilder;

import '../kernel/kernel_formal_parameter_builder.dart'
    show KernelFormalParameterBuilder;

import '../kernel/kernel_function_type_alias_builder.dart'
    show KernelFunctionTypeAliasBuilder;

import '../kernel/kernel_procedure_builder.dart'
    show KernelRedirectingFactoryBuilder;

import '../parser.dart' show Assert, MemberKind, Parser, optional;

import '../problems.dart' show DebugAbort, internalProblem, unexpected;

import '../type_inference/type_inference_engine.dart' show TypeInferenceEngine;

import '../type_inference/type_inference_listener.dart'
    show KernelTypeInferenceListener, TypeInferenceListener;

import 'source_library_builder.dart' show SourceLibraryBuilder;

import 'stack_listener.dart' show NullValue, StackListener;

import '../quote.dart' show unescapeString;

class DietListener extends StackListener {
  final SourceLibraryBuilder library;

  final ClassHierarchy hierarchy;

  final CoreTypes coreTypes;

  final bool enableNative;

  final bool stringExpectedAfterNative;

  final TypeInferenceEngine typeInferenceEngine;

  int importExportDirectiveIndex = 0;
  int partDirectiveIndex = 0;

  /// The unit currently being parsed, might be the same as [library] when
  /// the defining unit of the library is being parsed, updated from outside
  /// before parsing each part.
  SourceLibraryBuilder currentUnit;

  ClassBuilder currentClass;

  /// For top-level declarations, this is the library scope. For class members,
  /// this is the instance scope of [currentClass].
  Scope memberScope;

  @override
  Uri uri;

  DietListener(SourceLibraryBuilder library, this.hierarchy, this.coreTypes,
      this.typeInferenceEngine)
      : library = library,
        uri = library.fileUri,
        memberScope = library.scope,
        enableNative =
            library.loader.target.backendTarget.enableNative(library.uri),
        stringExpectedAfterNative =
            library.loader.target.backendTarget.nativeExtensionExpectsString;

  void discard(int n) {
    for (int i = 0; i < n; i++) {
      pop();
    }
  }

  @override
  void endMetadataStar(int count) {
    debugEvent("MetadataStar");
    push(popList(count, new List<Token>.filled(count, null, growable: true))
            ?.first ??
        NullValue.Metadata);
  }

  @override
  void endMetadata(Token beginToken, Token periodBeforeName, Token endToken) {
    debugEvent("Metadata");
    discard(periodBeforeName == null ? 1 : 2);
    push(beginToken);
  }

  @override
  void endPartOf(
      Token partKeyword, Token ofKeyword, Token semicolon, bool hasName) {
    debugEvent("PartOf");
    if (hasName) discard(1);
    Token metadata = pop();
    parseMetadata(currentUnit, metadata, currentUnit.target);
  }

  @override
  void handleInvalidTopLevelDeclaration(Token beginToken) {
    debugEvent("InvalidTopLevelDeclaration");
    pop(); // metadata star
  }

  @override
  void handleNoArguments(Token token) {
    debugEvent("NoArguments");
  }

  @override
  void handleNoTypeArguments(Token token) {
    debugEvent("NoTypeArguments");
  }

  @override
  void handleNoConstructorReferenceContinuationAfterTypeArguments(Token token) {
    debugEvent("NoConstructorReferenceContinuationAfterTypeArguments");
  }

  @override
  void handleNoType(Token lastConsumed) {
    debugEvent("NoType");
  }

  @override
  void handleType(Token beginToken) {
    debugEvent("Type");
    discard(1);
  }

  @override
  void endTypeList(int count) {
    debugEvent("TypeList");
  }

  @override
  void endMixinApplication(Token withKeyword) {
    debugEvent("MixinApplication");
  }

  @override
  void endTypeArguments(int count, Token beginToken, Token endToken) {
    debugEvent("TypeArguments");
  }

  @override
  void endFieldInitializer(Token assignmentOperator, Token token) {
    debugEvent("FieldInitializer");
  }

  @override
  void handleNoFieldInitializer(Token token) {
    debugEvent("NoFieldInitializer");
  }

  @override
  void handleNoTypeVariables(Token token) {
    debugEvent("NoTypeVariables");
  }

  @override
  void endFormalParameters(
      int count, Token beginToken, Token endToken, MemberKind kind) {
    debugEvent("FormalParameters");
    assert(count == 0); // Count is always 0 as the diet parser skips formals.
    if (kind != MemberKind.GeneralizedFunctionType &&
        identical(peek(), "-") &&
        identical(beginToken.next, endToken)) {
      pop();
      push("unary-");
    }
    push(beginToken);
  }

  @override
  void handleNoFormalParameters(Token token, MemberKind kind) {
    debugEvent("NoFormalParameters");
    if (identical(peek(), "-")) {
      pop();
      push("unary-");
    }
    push(token);
  }

  @override
  void endFunctionType(Token functionToken) {
    debugEvent("FunctionType");
    discard(1);
  }

  @override
  void endFunctionTypeAlias(
      Token typedefKeyword, Token equals, Token endToken) {
    debugEvent("FunctionTypeAlias");

    if (equals == null) pop(); // endToken
    String name = pop();
    Token metadata = pop();

    Declaration typedefBuilder = lookupBuilder(typedefKeyword, null, name);
    parseMetadata(typedefBuilder, metadata, typedefBuilder.target);
    if (typedefBuilder is KernelFunctionTypeAliasBuilder &&
        typedefBuilder.type != null &&
        typedefBuilder.type.formals != null) {
      for (int i = 0; i < typedefBuilder.type.formals.length; ++i) {
        KernelFormalParameterBuilder formal = typedefBuilder.type.formals[i];
        List<MetadataBuilder> metadata = formal.metadata;
        if (metadata != null && metadata.length > 0) {
          // [parseMetadata] is using [Parser.parseMetadataStar] under the hood,
          // so we only need the offset of the first annotation.
          Token metadataToken =
              tokenForOffset(typedefKeyword, endToken, metadata[0].charOffset);
          List<Expression> annotations =
              parseMetadata(typedefBuilder, metadataToken, null);
          if (formal.isPositional) {
            VariableDeclaration parameter =
                typedefBuilder.target.positionalParameters[i];
            for (Expression annotation in annotations) {
              parameter.addAnnotation(annotation);
            }
          } else {
            for (VariableDeclaration named
                in typedefBuilder.target.namedParameters) {
              if (named.name == formal.name) {
                for (Expression annotation in annotations) {
                  named.addAnnotation(annotation);
                }
              }
            }
          }
        }
      }
    }

    checkEmpty(typedefKeyword.charOffset);
  }

  @override
  void endFields(Token staticToken, Token covariantToken, Token varFinalOrConst,
      int count, Token beginToken, Token endToken) {
    debugEvent("Fields");
    buildFields(count, beginToken, false);
  }

  @override
  void handleAsyncModifier(Token asyncToken, Token startToken) {
    debugEvent("AsyncModifier");
  }

  @override
  void endTopLevelMethod(Token beginToken, Token getOrSet, Token endToken) {
    debugEvent("TopLevelMethod");
    Token bodyToken = pop();
    String name = pop();
    Token metadata = pop();
    checkEmpty(beginToken.charOffset);
    buildFunctionBody(bodyToken, lookupBuilder(beginToken, getOrSet, name),
        MemberKind.TopLevelMethod, metadata);
  }

  @override
  void handleNoFunctionBody(Token token) {
    debugEvent("NoFunctionBody");
  }

  @override
  void endTopLevelFields(Token staticToken, Token covariantToken,
      Token varFinalOrConst, int count, Token beginToken, Token endToken) {
    debugEvent("TopLevelFields");
    buildFields(count, beginToken, true);
  }

  @override
  void handleVoidKeyword(Token token) {
    debugEvent("VoidKeyword");
  }

  @override
  void handleNoInitializers() {
    debugEvent("NoInitializers");
  }

  @override
  void endInitializers(int count, Token beginToken, Token endToken) {
    debugEvent("Initializers");
  }

  @override
  void handleQualified(Token period) {
    debugEvent("handleQualified");
    String suffix = pop();
    var prefix = pop();
    push(new QualifiedName(prefix, suffix, period.charOffset));
  }

  @override
  void endLibraryName(Token libraryKeyword, Token semicolon) {
    debugEvent("endLibraryName");
    pop(); // name

    Token metadata = pop();
    parseMetadata(library, metadata, library.target);
  }

  @override
  void beginLiteralString(Token token) {
    debugEvent("beginLiteralString");
  }

  @override
  void handleStringPart(Token token) {
    debugEvent("StringPart");
  }

  @override
  void endLiteralString(int interpolationCount, Token endToken) {
    debugEvent("endLiteralString");
  }

  @override
  void handleNativeClause(Token nativeToken, bool hasName) {
    debugEvent("NativeClause");
  }

  @override
  void handleScript(Token token) {
    debugEvent("Script");
  }

  @override
  void handleStringJuxtaposition(int literalCount) {
    debugEvent("StringJuxtaposition");
  }

  @override
  void handleDottedName(int count, Token firstIdentifier) {
    debugEvent("DottedName");
    discard(count);
  }

  @override
  void endConditionalUri(Token ifKeyword, Token leftParen, Token equalSign) {
    debugEvent("ConditionalUri");
  }

  @override
  void endConditionalUris(int count) {
    debugEvent("ConditionalUris");
  }

  @override
  void handleOperatorName(Token operatorKeyword, Token token) {
    debugEvent("OperatorName");
    push(token.stringValue);
  }

  @override
  void handleInvalidOperatorName(Token operatorKeyword, Token token) {
    debugEvent("InvalidOperatorName");
    push('invalid');
  }

  @override
  void handleIdentifierList(int count) {
    debugEvent("IdentifierList");
    discard(count);
  }

  @override
  void endShow(Token showKeyword) {
    debugEvent("Show");
  }

  @override
  void endHide(Token hideKeyword) {
    debugEvent("Hide");
  }

  @override
  void endCombinators(int count) {
    debugEvent("Combinators");
  }

  @override
  void handleImportPrefix(Token deferredKeyword, Token asKeyword) {
    debugEvent("ImportPrefix");
    pushIfNull(asKeyword, NullValue.Prefix);
  }

  @override
  void endImport(Token importKeyword, Token semicolon) {
    debugEvent("Import");
    pop(NullValue.Prefix);

    Token metadata = pop();

    // Native imports must be skipped because they aren't assigned corresponding
    // LibraryDependency nodes.
    Token importUriToken = importKeyword.next;
    String importUri =
        unescapeString(importUriToken.lexeme, importUriToken, this);
    if (importUri.startsWith("dart-ext:")) return;

    Library libraryNode = library.target;
    LibraryDependency dependency =
        libraryNode.dependencies[importExportDirectiveIndex++];
    parseMetadata(library, metadata, dependency);
  }

  @override
  void handleRecoverImport(Token semicolon) {
    pop(NullValue.Prefix);
  }

  @override
  void endExport(Token exportKeyword, Token semicolon) {
    debugEvent("Export");

    Token metadata = pop();
    Library libraryNode = library.target;
    LibraryDependency dependency =
        libraryNode.dependencies[importExportDirectiveIndex++];
    parseMetadata(library, metadata, dependency);
  }

  @override
  void endPart(Token partKeyword, Token semicolon) {
    debugEvent("Part");

    Token metadata = pop();
    Library libraryNode = library.target;
    LibraryPart part = libraryNode.parts[partDirectiveIndex++];
    parseMetadata(library, metadata, part);
  }

  @override
  void beginTypeVariable(Token token) {
    debugEvent("beginTypeVariable");
    discard(2); // Name and metadata.
  }

  @override
  void endTypeVariable(Token token, int index, Token extendsOrSuper) {
    debugEvent("endTypeVariable");
  }

  @override
  void endTypeVariables(Token beginToken, Token endToken) {
    debugEvent("TypeVariables");
  }

  @override
  void endConstructorReference(
      Token start, Token periodBeforeName, Token endToken) {
    debugEvent("ConstructorReference");
    popIfNotNull(periodBeforeName);
  }

  @override
  void endFactoryMethod(
      Token beginToken, Token factoryKeyword, Token endToken) {
    debugEvent("FactoryMethod");
    Token bodyToken = pop();
    Object name = pop();
    Token metadata = pop();
    checkEmpty(beginToken.charOffset);
    if (bodyToken == null || optional("=", bodyToken.endGroup.next)) {
      // TODO(dmitryas): Consider building redirecting factory bodies here.
      KernelRedirectingFactoryBuilder factory =
          lookupConstructor(beginToken, name);
      parseMetadata(factory, metadata, factory.target);

      if (factory.formals != null) {
        List<int> metadataOffsets = new List<int>(factory.formals.length);
        for (int i = 0; i < factory.formals.length; ++i) {
          List<MetadataBuilder> metadata = factory.formals[i].metadata;
          if (metadata != null && metadata.length > 0) {
            // [parseMetadata] is using [Parser.parseMetadataStar] under the
            // hood, so we only need the offset of the first annotation.
            metadataOffsets[i] = metadata[0].charOffset;
          } else {
            metadataOffsets[i] = -1;
          }
        }
        List<Token> metadataTokens =
            tokensForOffsets(beginToken, endToken, metadataOffsets);
        for (int i = 0; i < factory.formals.length; ++i) {
          Token metadata = metadataTokens[i];
          if (metadata == null) continue;
          parseMetadata(
              factory.formals[i], metadata, factory.formals[i].target);
        }
      }
      return;
    }
    buildFunctionBody(bodyToken, lookupConstructor(beginToken, name),
        MemberKind.Factory, metadata);
  }

  @override
  void endRedirectingFactoryBody(Token beginToken, Token endToken) {
    debugEvent("RedirectingFactoryBody");
    discard(1); // ConstructorReference.
  }

  @override
  void handleNativeFunctionBody(Token nativeToken, Token semicolon) {
    debugEvent("NativeFunctionBody");
  }

  @override
  void handleNativeFunctionBodyIgnored(Token nativeToken, Token semicolon) {
    debugEvent("NativeFunctionBodyIgnored");
  }

  @override
  void handleNativeFunctionBodySkipped(Token nativeToken, Token semicolon) {
    debugEvent("NativeFunctionBodySkipped");
    if (!enableNative) {
      super.handleRecoverableError(
          messageExpectedBlockToSkip, nativeToken, nativeToken);
    }
  }

  @override
  void endMethod(
      Token getOrSet, Token beginToken, Token beginParam, Token endToken) {
    debugEvent("Method");
    // TODO(danrubel): Consider removing the beginParam parameter
    // and using bodyToken, but pushing a NullValue on the stack
    // in handleNoFormalParameters rather than the supplied token.
    pop(); // bodyToken
    Object name = pop();
    Token metadata = pop();
    checkEmpty(beginToken.charOffset);
    ProcedureBuilder builder;
    if (name is QualifiedName ||
        (getOrSet == null && name == currentClass.name)) {
      builder = lookupConstructor(beginToken, name);
    } else {
      builder = lookupBuilder(beginToken, getOrSet, name);
    }
    buildFunctionBody(
        beginParam,
        builder,
        builder.isStatic ? MemberKind.StaticMethod : MemberKind.NonStaticMethod,
        metadata);
  }

  StackListener createListener(
      ModifierBuilder builder, Scope memberScope, bool isInstanceMember,
      [Scope formalParameterScope,
      TypeInferenceListener<int, Node, int> listener]) {
    listener ??= new KernelTypeInferenceListener();
    // Note: we set thisType regardless of whether we are building a static
    // member, since that provides better error recovery.
    InterfaceType thisType = currentClass?.target?.thisType;
    var typeInferrer = library.disableTypeInference
        ? typeInferenceEngine.createDisabledTypeInferrer()
        : typeInferenceEngine.createLocalTypeInferrer(
            uri, listener, thisType, library);
    ConstantContext constantContext = builder.isConstructor && builder.isConst
        ? ConstantContext.inferred
        : ConstantContext.none;
    return new KernelBodyBuilder(
        library,
        builder,
        memberScope,
        formalParameterScope,
        hierarchy,
        coreTypes,
        currentClass,
        isInstanceMember,
        uri,
        typeInferrer)
      ..constantContext = constantContext;
  }

  void buildFunctionBody(
      Token token, ProcedureBuilder builder, MemberKind kind, Token metadata) {
    Scope typeParameterScope = builder.computeTypeParameterScope(memberScope);
    Scope formalParameterScope =
        builder.computeFormalParameterScope(typeParameterScope);
    assert(typeParameterScope != null);
    assert(formalParameterScope != null);
    parseFunctionBody(
        createListener(builder, typeParameterScope, builder.isInstanceMember,
            formalParameterScope),
        token,
        metadata,
        kind);
  }

  void buildFields(int count, Token token, bool isTopLevel) {
    List<String> names =
        popList(count, new List<String>.filled(count, null, growable: true));
    Declaration declaration = lookupBuilder(token, null, names.first);
    Token metadata = pop();
    // TODO(paulberry): don't re-parse the field if we've already parsed it
    // for type inference.
    parseFields(
        createListener(declaration, memberScope, declaration.isInstanceMember),
        token,
        metadata,
        isTopLevel);
  }

  @override
  void handleInvalidMember(Token endToken) {
    debugEvent("InvalidMember");
    pop(); // metadata star
  }

  @override
  void endMember() {
    debugEvent("Member");
    checkEmpty(-1);
  }

  @override
  void endAssert(Token assertKeyword, Assert kind, Token leftParenthesis,
      Token commaToken, Token semicolonToken) {
    debugEvent("Assert");
    // Do nothing
  }

  @override
  void beginClassOrMixinBody(Token token) {
    debugEvent("beginClassBody");
    String name = pop();
    Token metadata = pop();
    assert(currentClass == null);
    assert(memberScope == library.scope);

    Declaration classBuilder = lookupBuilder(token, null, name);
    parseMetadata(classBuilder, metadata, classBuilder.target);

    currentClass = classBuilder;
    memberScope = currentClass.scope;
  }

  @override
  void endClassOrMixinBody(int memberCount, Token beginToken, Token endToken) {
    debugEvent("ClassOrMixinBody");
    currentClass = null;
    memberScope = library.scope;
  }

  @override
  void endClassDeclaration(Token beginToken, Token endToken) {
    debugEvent("ClassDeclaration");
    checkEmpty(beginToken.charOffset);
  }

  @override
  void endEnum(Token enumKeyword, Token leftBrace, int count) {
    debugEvent("Enum");

    List metadataAndValues = new List.filled(count * 2, null, growable: true);
    popList(count * 2, metadataAndValues);

    String name = pop();
    Token metadata = pop();

    ClassBuilder enumBuilder = lookupBuilder(enumKeyword, null, name);
    parseMetadata(enumBuilder, metadata, enumBuilder.target);
    for (int i = 0; i < metadataAndValues.length; i += 2) {
      Token metadata = metadataAndValues[i];
      String valueName = metadataAndValues[i + 1];
      Declaration declaration = enumBuilder.scope.local[valueName];
      if (metadata != null) {
        parseMetadata(declaration, metadata, declaration.target);
      }
    }

    checkEmpty(enumKeyword.charOffset);
  }

  @override
  void endNamedMixinApplication(Token beginToken, Token classKeyword,
      Token equals, Token implementsKeyword, Token endToken) {
    debugEvent("NamedMixinApplication");

    String name = pop();
    Token metadata = pop();

    Declaration classBuilder = lookupBuilder(classKeyword, null, name);
    parseMetadata(classBuilder, metadata, classBuilder.target);

    checkEmpty(beginToken.charOffset);
  }

  AsyncMarker getAsyncMarker(StackListener listener) => listener.pop();

  /// Invokes the listener's [finishFunction] method.
  ///
  /// This is a separate method so that it may be overridden by a derived class
  /// if more computation must be done before finishing the function.
  void listenerFinishFunction(
      StackListener listener,
      Token token,
      Token metadata,
      MemberKind kind,
      List metadataConstants,
      dynamic formals,
      AsyncMarker asyncModifier,
      dynamic body) {
    listener.finishFunction(metadataConstants, formals, asyncModifier, body);
  }

  /// Invokes the listener's [finishFields] method.
  ///
  /// This is a separate method so that it may be overridden by a derived class
  /// if more computation must be done before finishing the function.
  void listenerFinishFields(StackListener listener, Token startToken,
      Token metadata, bool isTopLevel) {
    listener.finishFields();
  }

  void parseFunctionBody(StackListener listener, Token startToken,
      Token metadata, MemberKind kind) {
    Token token = startToken;
    try {
      Parser parser = new Parser(listener);
      List metadataConstants;
      if (metadata != null) {
        parser.parseMetadataStar(parser.syntheticPreviousToken(metadata));
        metadataConstants = listener.pop();
      }
      token = parser.parseFormalParametersOpt(
          parser.syntheticPreviousToken(token), kind);
      var formals = listener.pop();
      listener.checkEmpty(token.next.charOffset);
      token = parser.parseInitializersOpt(token);
      token = parser.parseAsyncModifierOpt(token);
      AsyncMarker asyncModifier = getAsyncMarker(listener) ?? AsyncMarker.Sync;
      bool isExpression = false;
      bool allowAbstract = asyncModifier == AsyncMarker.Sync;
      parser.parseFunctionBody(token, isExpression, allowAbstract);
      var body = listener.pop();
      listener.checkEmpty(token.charOffset);
      listenerFinishFunction(listener, startToken, metadata, kind,
          metadataConstants, formals, asyncModifier, body);
    } on DebugAbort {
      rethrow;
    } on deprecated_InputError {
      rethrow;
    } catch (e, s) {
      throw new Crash(uri, token.charOffset, e, s);
    }
  }

  void parseFields(StackListener listener, Token startToken, Token metadata,
      bool isTopLevel) {
    Token token = startToken;
    Parser parser = new Parser(listener);
    if (isTopLevel) {
      token = parser.parseTopLevelMember(metadata ?? token);
    } else {
      token = parser.parseClassOrMixinMember(metadata ?? token).next;
    }
    listenerFinishFields(listener, startToken, metadata, isTopLevel);
    listener.checkEmpty(token.charOffset);
  }

  Declaration lookupBuilder(Token token, Token getOrSet, String name) {
    // TODO(ahe): Can I move this to Scope or ScopeBuilder?
    Declaration declaration;
    if (currentClass != null) {
      if (uri != currentClass.fileUri) {
        unexpected("$uri", "${currentClass.fileUri}", currentClass.charOffset,
            currentClass.fileUri);
      }

      if (getOrSet != null && optional("set", getOrSet)) {
        declaration = currentClass.scope.setters[name];
      } else {
        declaration = currentClass.scope.local[name];
      }
    } else if (getOrSet != null && optional("set", getOrSet)) {
      declaration = library.scope.setters[name];
    } else {
      declaration = library.scopeBuilder[name];
    }
    checkBuilder(token, declaration, name);
    return declaration;
  }

  Declaration lookupConstructor(Token token, Object nameOrQualified) {
    assert(currentClass != null);
    Declaration declaration;
    String name;
    String suffix;
    if (nameOrQualified is QualifiedName) {
      name = nameOrQualified.prefix;
      suffix = nameOrQualified.suffix;
    } else {
      name = nameOrQualified;
      suffix = name == currentClass.name ? "" : name;
    }
    declaration = currentClass.constructors.local[suffix];
    checkBuilder(token, declaration, nameOrQualified);
    return declaration;
  }

  void checkBuilder(Token token, Declaration declaration, Object name) {
    if (declaration == null) {
      internalProblem(templateInternalProblemNotFound.withArguments("$name"),
          token.charOffset, uri);
    }
    if (declaration.next != null) {
      deprecated_inputError(uri, token.charOffset, "Duplicated name: $name");
    }
    if (uri != declaration.fileUri) {
      unexpected("$uri", "${declaration.fileUri}", declaration.charOffset,
          declaration.fileUri);
    }
  }

  @override
  void addCompileTimeError(Message message, int charOffset, int length) {
    library.addCompileTimeError(message, charOffset, length, uri);
  }

  void addProblem(Message message, int charOffset, int length) {
    library.addProblem(message, charOffset, length, uri);
  }

  @override
  void debugEvent(String name) {
    // printEvent('DietListener: $name');
  }

  /// If the [metadata] is not `null`, return the parsed metadata [Expression]s.
  /// Otherwise, return `null`.
  List<Expression> parseMetadata(
      ModifierBuilder builder, Token metadata, TreeNode parent) {
    if (metadata != null) {
      var listener = createListener(builder, memberScope, false);
      var parser = new Parser(listener);
      parser.parseMetadataStar(parser.syntheticPreviousToken(metadata));
      return listener.finishMetadata(parent);
    }
    return null;
  }

  /// Returns [Token] found between [start] (inclusive) and [end]
  /// (non-inclusive) that has its [Token.charOffset] equal to [offset].  If
  /// there is no such token, null is returned.
  Token tokenForOffset(Token start, Token end, int offset) {
    if (offset < start.charOffset || offset >= end.charOffset) {
      return null;
    }
    while (start != end) {
      if (offset == start.charOffset) {
        return start;
      }
      start = start.next;
    }
    return null;
  }

  /// Returns list of [Token]s found between [start] (inclusive) and [end]
  /// (non-inclusive) that correspond to [offsets].  If there's no token between
  /// [start] and [end] for the given offset, the corresponding item in the
  /// resulting list is set to null.  [offsets] are assumed to be in ascending
  /// order.
  List<Token> tokensForOffsets(Token start, Token end, List<int> offsets) {
    List<Token> result =
        new List<Token>.filled(offsets.length, null, growable: false);
    for (int i = 0; start != end && i < offsets.length;) {
      int offset = offsets[i];
      if (offset < start.charOffset) {
        ++i;
      } else if (offset == start.charOffset) {
        result[i] = start;
        start = start.next;
      } else {
        start = start.next;
      }
    }
    return result;
  }
}
