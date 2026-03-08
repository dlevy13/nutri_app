import 'package:logger/logger.dart';

import '../logger.dart';

class BaseService {
  late final Logger log;

  BaseService({String? title}) {
    log = getLogger(title ?? runtimeType.toString());
  }
}