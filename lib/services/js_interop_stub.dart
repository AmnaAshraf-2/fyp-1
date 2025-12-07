// Stub file for non-web platforms
// This file provides stub implementations when dart:js is not available

// Stub implementations that will never be called on non-web platforms
// since all web-specific code is guarded by kIsWeb checks

class _JsContext {
  dynamic operator [](String key) => null;
  dynamic callMethod(String method, List<dynamic> args) => null;
}

final context = _JsContext();

class JsObject {
  JsObject(dynamic constructor, List<dynamic> args);
  dynamic operator [](String key) => null;
  void operator []=(String key, dynamic value) {}
  dynamic callMethod(String method, List<dynamic> args) => null;
  
  static dynamic jsify(Map map) => map;
}

class JsArray {
  List<dynamic> toList() => [];
}

dynamic allowInterop(Function function) => function;

