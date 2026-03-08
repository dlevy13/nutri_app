// Stub implementation of web package for non-web platforms
// This file is used when building for Android/iOS/Desktop

class Window {
  final Location location = Location();
  final Navigator navigator = Navigator();
  final Storage localStorage = Storage();
  
  void open(String url, String target) {
    // No-op on non-web platforms
  }
}

class Location {
  String href = '';
}

class Navigator {
  String userAgent = '';
}

class Storage {
  String? getItem(String key) => null;
  void setItem(String key, String value) {}
  void removeItem(String key) {}
}

final window = Window();

