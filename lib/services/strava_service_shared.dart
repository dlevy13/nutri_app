import 'package:firebase_auth/firebase_auth.dart';

abstract class StravaServiceShared {
  Future<void> launchAuthUrl(String uid);
  Future<void> exchangeToken(String code);
  Future<void> refreshAccessToken();
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<void> disconnect();
  Future<bool> isConnected();
  Future<List<dynamic>> getActivitiesForDay(DateTime date);
  Future<Map<String, dynamic>?> getActivityDetails(int id);
}
