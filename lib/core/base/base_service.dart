import 'package:logger/logger.dart';

import '../logger.dart';

class BaseService {
  late Logger log;

  BaseService({String? title}) {
    this.log = getLogger(
      title ?? this.runtimeType.toString(),
    );
  }
}