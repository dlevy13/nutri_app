import '../../core/base/base_service.dart';
import 'package:flutter/material.dart';

class NavigatorService extends BaseService {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Future<T> navigateToPage<T>(MaterialPageRoute<T> pageRoute) async {
    log.i('navigateToPage: pageRoute: ${pageRoute.settings.name}');
    final state = navigatorKey.currentState;
    if (state == null) {
      log.e('navigateToPage: Navigator State is null');
      throw StateError('Navigator state is null');
    }
    return state.push(pageRoute) as Future<T>;
  }

  Future<T> navigateToPageWithReplacement<T>(
      MaterialPageRoute<T> pageRoute) async {
    log.i('navigateToPageWithReplacement: '
      'pageRoute: ${pageRoute.settings.name}');
    final state = navigatorKey.currentState;
    if (state == null) {
      log.e('navigateToPageWithReplacement: Navigator State is null');
      throw StateError('Navigator state is null');
    }
    return state.pushReplacement(pageRoute) as Future<T>;
  }

  void pop<T>([T? result]) {
    log.i('goBack:');
    final state = navigatorKey.currentState;
    if (state == null) {
      log.e('goBack: Navigator State is null');
      return;
    }
    state.pop(result);
  }
}