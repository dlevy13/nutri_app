//Utilitaires pour traitement de texte (normalisation, raccourcissement, etc.)
import 'package:hive/hive.dart';

part 'analysis.g.dart';

@HiveType(typeId: 2)
class Analysis extends HiveObject {
  @HiveField(0)
  String date;

  @HiveField(1)
  String result;

  @HiveField(2)
  DateTime createdAt;

  Analysis({
  
    required this.date,
    required this.result,
    required this.createdAt,
  });
}
