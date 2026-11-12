import 'dart:async';

class AppLinksBridge {
  Future<Uri?> getInitialAppLink() async => null;

  Stream<Uri> get uriLinkStream => const Stream<Uri>.empty();
}
