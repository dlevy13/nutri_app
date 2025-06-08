import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

final logger = Logger(
  level: kReleaseMode ? Level.off : Level.debug, // Remplacer 'nothing' par 'off'
  printer: PrettyPrinter(),
);

//pour afficher le message dans la console de débog
//final date = DateFormat('yyyy-MM-dd').format(selectedDate); //pour tester la date
  //logger.d("Chargement des repas pour la date : $date");