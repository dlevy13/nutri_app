import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
//import 'package:intl/intl.dart';

class MealDatabaseService {
  static final MealDatabaseService _instance = MealDatabaseService._internal();
  factory MealDatabaseService() => _instance;

  MealDatabaseService._internal();

  Database? _db;

  Future<void> init() async {
    _db ??= await _initDatabase();
  }

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
  final dbPath = await getDatabasesPath();
  final path = join(dbPath, 'meals.db');

  return await openDatabase(
    path,
    version: 2, // ⬅️ Change la version pour forcer le onUpgrade
    onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE meals (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          calories REAL,
          protein REAL,
          carbs REAL,
          fat REAL,
          quantity REAL,
          mealType TEXT,
          date TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE custom_foods (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          calories REAL,
          proteins REAL,
          carbs REAL,
          fats REAL
        )
      ''');
    },
    onUpgrade: (db, oldV, newV) async {
      if (oldV < 2) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS custom_foods (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            calories REAL,
            proteins REAL,
            carbs REAL,
            fats REAL
          )
        ''');
      }
      // if (oldV < 3) { // future migration… }
    },
  );
}


  Future<void> addMeal(
  String name,
  double calories,
  double protein,
  double carbs,
  double fat,
  double quantity,
  String mealType,
  String date,
) async {
  final db = await database;

  // Insérer les données calculées directement dans la base de données
  await db.insert('meals', {
    'name': name,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'quantity': quantity,
    'mealType': mealType,
    'date': date,
  });
}


  Future<List<Map<String, dynamic>>> getMeals({
    required String mealType,
    required String date,
  }) async {
    final db = await database;
    return await db.query(
      'meals',
      where: 'mealType = ? AND date = ?',
      whereArgs: [mealType, date],
    );
  }

  Future<void> removeMeal(int id) async {
    final db = await database;
    await db.delete('meals', where: 'id = ?', whereArgs: [id]);
  }

  // Méthode pour supprimer toutes les entrées de repas
  Future<void> resetDatabase() async {
    final db = await database;
    await db.delete('meals'); // Supprime toutes les entrées de repas
  }

  //fermeture de la base quand l'app se ferme
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }

  // Méthode pour supprimer le fichier de la base de données
  Future<void> deleteDatabaseFile() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'meals.db');
    final file = File(path);

    if (await file.exists()) {
      await file.delete(); // Supprime le fichier de la base de données
    }
  }
  // Méthode pour ajouter un aliment personnalisé
    Future<void> addCustomFood(Map<String, dynamic> food) async {
      final db = await database;
      await db.insert('custom_foods', food);
    }

    Future<List<Map<String, dynamic>>> getCustomFoods() async {
      final db = await database;
      return await db.query('custom_foods');
    }

// Méthode pour rechercher des aliments personnalisés
Future<List<Map<String, dynamic>>> searchFoods(String query) async {
  final db = await database;

  // Utiliser le SQL LIKE pour rechercher par nom
  return await db.query(
    'custom_foods',
    where: 'name LIKE ?',
    whereArgs: ['%$query%'], // Utilisation de % pour une recherche partielle
  );
}

  // Récupérer les repas pour toute la semaine (optionnel)
 Future<Map<String, List<Map<String, dynamic>>>> getMealsForTheWeek() async {
  final db  = await database;
  final now = DateTime.now();
  final monday = now.subtract(Duration(days: now.weekday - 1));

  final Map<String, List<Map<String, dynamic>>> weeklyMeals = {};

  for (var offset = 0; offset < 7; offset++) {
    final day = monday.add(Duration(days: offset));
    final formatted = 
      '${day.year}-${day.month.toString().padLeft(2,'0')}-${day.day.toString().padLeft(2,'0')}';
    final rows = await db.query(
      'meals',
      where: 'date = ?',
      whereArgs: [formatted],
    );
    weeklyMeals[formatted] = rows;
  }
  return weeklyMeals;
}
}
