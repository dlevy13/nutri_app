// Run with: flutter test --platform chrome test/browser/food_search_web.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_app/meal_input/meal_input_notifier.dart';
import 'package:nutri_app/meal_input/meal_input_state.dart';
import 'package:nutri_app/models/meal.dart';
import 'package:nutri_app/services/search_api_service.dart';
import 'package:nutri_app/providers/common_providers.dart'
    show mealRepositoryProvider;
import 'package:nutri_app/repositories/food_api_repository.dart';
import 'package:nutri_app/repositories/food_cache_repository.dart.dart';
import 'package:nutri_app/repositories/meal_repository.dart';
import 'package:nutri_app/repositories/user_repository.dart';

Meal _meal(String name, String date) => Meal(
    name: name,
    calories: 100,
    protein: 10,
    carbs: 10,
    fat: 2,
    quantity: 100,
    type: 'Déjeuner',
    date: date,
    timestamp: '${date}T12:00:00');

class _Meals extends Fake implements MealRepository {
  @override
  Future<List<Meal>> getAllRecentMeals() async => [
        _meal('Petit pot légumes', '2026-11-14'),
        _meal('Bouillon de pot-au-feu', '2026-11-13'),
        _meal('Pot-au-feu', '2026-01-01'),
      ];
  @override
  Future<List<Meal>> getLastMealsByType(String mealType) async => [];
  @override
  Future<List<Meal>> getMealsForTypeAndDate(
          String mealType, String date) async =>
      [];
}

class _Users extends Fake implements UserRepository {
  Future<List<Meal>> Function()? respond;
  @override
  Future<List<Meal>> getCustomFoods() => respond?.call() ?? Future.value([]);
}

class _Cache extends Fake implements FoodCacheRepository {
  final requests = <String>[];
  final pending = <Completer<List<Map<String, dynamic>>>>[];
  final savedQueries = <String>[];
  @override
  Future<void> saveMany(String query, List<Map<String, dynamic>> items) async {
    savedQueries.add(query);
  }

  @override
  Future<List<Map<String, dynamic>>> searchFoods(String query) {
    requests.add(query);
    final result = Completer<List<Map<String, dynamic>>>();
    pending.add(result);
    return result.future;
  }
}

class _Api extends Fake implements FoodAPIRepository {
  int requests = 0;
  final queries = <String>[];
  Future<List<Map<String, dynamic>>> Function(String)? respond;
  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    requests++;
    queries.add(query);
    return respond == null ? [] : await respond!(query);
  }
}

final _provider = mealInputProvider(
    (mealType: 'Déjeuner', selectedDate: '2026-11-14', fullTimestamp: null));

Map<String, dynamic> _local(String name, {String group = ''}) => {
      'name': name,
      'group': group,
      'calories': 100,
      'protein': 10,
      'carbs': 10,
      'fat': 2,
    };
Map<String, dynamic> _result(String name) => {
      'product_name': name,
      'source': 'api',
      'code': name,
      'nutriments': <String, dynamic>{'energy-kcal_100g': 100.0},
    };

Future<
        ({
          ProviderContainer container,
          _Cache cache,
          _Api api,
          void Function() close
        })>
    _setup(WidgetTester tester,
        {List<Map<String, dynamic>> local = const [],
        _Api? api,
        _Users? users,
        FoodSearchRequest? fatSecret}) async {
  rootBundle.evict('assets/food_data.json');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMessageHandler('flutter/assets', (message) async {
    final key = utf8.decode(message!.buffer
        .asUint8List(message.offsetInBytes, message.lengthInBytes));
    if (key != 'assets/food_data.json') return null;
    return ByteData.sublistView(
        Uint8List.fromList(utf8.encode(jsonEncode(local))));
  });
  addTearDown(() {
    messenger.setMockMessageHandler('flutter/assets', null);
    rootBundle.evict('assets/food_data.json');
  });
  final cache = _Cache();
  final remote = api ?? _Api();
  final container = ProviderContainer(overrides: [
    mealRepositoryProvider.overrideWithValue(_Meals()),
    userRepositoryProvider.overrideWithValue(users ?? _Users()),
    foodCacheRepositoryProvider.overrideWithValue(cache),
    foodApiRepositoryProvider.overrideWithValue(remote),
    if (fatSecret != null)
      fatSecretFoodSearchProvider.overrideWithValue(fatSecret),
  ]);
  final subscription = container.listen(_provider, (_, __) {});
  var closed = false;
  void close() {
    if (closed) return;
    closed = true;
    subscription.close();
    container.dispose();
  }

  addTearDown(close);
  await tester.pump();
  return (container: container, cache: cache, api: remote, close: close);
}

Future<void> _start(
    WidgetTester tester, ProviderContainer container, String query) async {
  container.read(_provider.notifier).searchFood(query);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}

void main() {
  testWidgets(
      'local results and history rank before and after a delayed cache response',
      (tester) async {
    final foods = [
      'Bouillon de viande type pot-au-feu',
      'Boeuf à pot-au-feu cuit',
      'Bouillon de pot-au-feu déshydraté',
      'Boeuf à pot-au-feu cru',
      'Bouillon de pot-au-feu dégraissé',
      'Pot-au-feu préemballé',
      'Petit pot légumes',
    ]
        .map((name) => {
              'name': name,
              'group': name.startsWith('Petit')
                  ? 'petits pots salés et plats infantiles'
                  : 'plats composés',
              'calories': 100,
              'protein': 10,
              'carbs': 10,
              'fat': 2
            })
        .toList();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets', (message) async {
      final key = utf8.decode(message!.buffer
          .asUint8List(message.offsetInBytes, message.lengthInBytes));
      if (key != 'assets/food_data.json') return null;
      return ByteData.sublistView(
          Uint8List.fromList(utf8.encode(jsonEncode(foods))));
    });
    addTearDown(() => messenger.setMockMessageHandler('flutter/assets', null));
    final cache = _Cache();
    final api = _Api();
    final container = ProviderContainer(overrides: [
      mealRepositoryProvider.overrideWithValue(_Meals()),
      userRepositoryProvider.overrideWithValue(_Users()),
      foodCacheRepositoryProvider.overrideWithValue(cache),
      foodApiRepositoryProvider.overrideWithValue(api),
    ]);
    addTearDown(container.dispose);
    final provider = mealInputProvider((
      mealType: 'Déjeuner',
      selectedDate: '2026-11-14',
      fullTimestamp: null
    ));
    final subscription = container.listen(provider, (_, __) {});
    addTearDown(subscription.close);
    await tester.pump();
    List<String>? expected;
    for (final query in ['pot au feu', 'pot-au-feu', 'Pot   au feu']) {
      container.read(provider.notifier).searchFood(query);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      final local = container.read(provider);
      expect(local.status, SearchStatus.success);
      expect(local.searchSuggestions.first['product_name'],
          'Pot-au-feu préemballé');
      expect(local.historySearchSuggestions.map((m) => m.name),
          ['Pot-au-feu', 'Bouillon de pot-au-feu']);
      expect(cache.requests.last, query); // Transport queries remain unchanged.
      cache.pending.last.complete([
        {
          'product_name': 'Petit pot légumes',
          'source': 'api',
          'group': 'petits pots salés et plats infantiles'
        },
        {
          'product_name': 'Plat légumes avec féculents',
          'group': 'petits pots salés et plats infantiles'
        },
      ]);
      await tester.pump();
      final names = container
          .read(provider)
          .searchSuggestions
          .map((r) => r['product_name'] as String)
          .toList();
      expected ??= names;
      expect(names, expected);
      expect(names.first, 'Pot-au-feu préemballé');
      expect(names, isNot(contains('Petit pot légumes')));
    }
    expect(api.requests, 0); // Existing five-candidate threshold is preserved.
  });
  testWidgets(
      'category counts and unrelated cache results cannot suppress online search',
      (tester) async {
    final h = await _setup(tester,
        local: List.generate(
            10, (i) => _local('Plat préparé $i', group: 'riz et pâtes')));
    await _start(tester, h.container, 'riz');
    h.cache.pending.single
        .complete(List.generate(10, (i) => _result('Petit pot légumes $i')));
    await tester.pump();
    expect(h.api.queries, ['riz']);
  });

  testWidgets('five distinct strong local/cache names avoid online search',
      (tester) async {
    final h = await _setup(tester,
        local: [_local('Riz blanc'), _local('Riz complet')]);
    await _start(tester, h.container, 'riz');
    h.cache.pending.single.complete(
        [_result('Riz basmati'), _result('Riz thaï'), _result('Riz rouge')]);
    await tester.pump();
    expect(h.api.requests, 0);
    expect(h.container.read(_provider).searchSuggestions, hasLength(5));
  });

  testWidgets('useful cache results display while the API is still pending',
      (tester) async {
    final pending = Completer<List<Map<String, dynamic>>>();
    final h =
        await _setup(tester, api: _Api()..respond = (_) => pending.future);
    await _start(tester, h.container, 'riz');
    h.cache.pending.single.complete([_result('Riz complet')]);
    await tester.pump();
    expect(h.api.requests, 1);
    expect(h.container.read(_provider).searchSuggestions.single['product_name'],
        'Riz complet');
    pending.complete([_result('Riz basmati')]);
    await tester.pump();
    expect(h.container.read(_provider).searchSuggestions, hasLength(2));
    expect(h.cache.savedQueries, ['riz']);
  });

  testWidgets(
      'a new input invalidates a cache response during the debounce window',
      (tester) async {
    final h = await _setup(tester);
    await _start(tester, h.container, 'riz');
    h.container.read(_provider.notifier).searchFood('pomme');
    h.cache.pending.first.complete(List.generate(5, (i) => _result('Riz $i')));
    await tester.pump();
    expect(h.container.read(_provider).searchSuggestions, isEmpty);
    expect(h.container.read(_provider).status, SearchStatus.loading);
    expect(h.api.requests, 0);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    h.cache.pending.last.complete(List.generate(5, (i) => _result('Pomme $i')));
    await tester.pump();
    expect(
        h.container
            .read(_provider)
            .searchSuggestions
            .every((r) => r['product_name'].startsWith('Pomme')),
        isTrue);
  });

  for (final fail in [false, true]) {
    testWidgets(
        'old API ${fail ? 'failure' : 'success'} cannot replace newer results',
        (tester) async {
      final pending = <String, Completer<List<Map<String, dynamic>>>>{};
      final h = await _setup(tester,
          api: _Api()
            ..respond = (q) =>
                (pending[q] = Completer<List<Map<String, dynamic>>>()).future);
      await _start(tester, h.container, 'riz');
      h.cache.pending.first.complete([]);
      await tester.pump();
      await _start(tester, h.container, 'pomme');
      h.cache.pending.last.complete([]);
      await tester.pump();
      pending['pomme']!.complete([_result('Pomme fraîche')]);
      await tester.pump();
      if (fail) {
        pending['riz']!.completeError(Exception('old request'));
      } else {
        pending['riz']!.complete([_result('Riz complet')]);
      }
      await tester.pump();
      final state = h.container.read(_provider);
      expect(state.searchSuggestions.single['product_name'], 'Pomme fraîche');
      expect(state.status, SearchStatus.success);
      expect(h.cache.savedQueries, ['pomme']);
    });
  }

  for (final action in ['clear', 'short input', 'meal change', 'dispose']) {
    testWidgets('$action invalidates an in-flight API request', (tester) async {
      final pending = Completer<List<Map<String, dynamic>>>();
      final h =
          await _setup(tester, api: _Api()..respond = (_) => pending.future);
      await _start(tester, h.container, 'riz');
      h.cache.pending.single.complete([]);
      await tester.pump();
      final notifier = h.container.read(_provider.notifier);
      switch (action) {
        case 'clear':
          notifier.clearSearch();
        case 'short input':
          notifier.searchFood('ri');
        case 'meal change':
          notifier.changeMealType('Dîner');
        case 'dispose':
          h.close();
      }
      pending.complete([_result('Riz complet')]);
      await tester.pumpAndSettle();
      if (action != 'dispose') {
        expect(h.container.read(_provider).searchSuggestions, isEmpty);
        expect(h.container.read(_provider).status, SearchStatus.initial);
      }
      expect(h.cache.savedQueries, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  for (final dispose in [false, true]) {
    testWidgets('${dispose ? 'dispose' : 'clear'} cancels a scheduled search',
        (tester) async {
      final h = await _setup(tester);
      h.container.read(_provider.notifier).searchFood('riz');
      if (dispose) {
        h.close();
      } else {
        h.container.read(_provider.notifier).clearSearch();
      }
      await tester.pump(const Duration(milliseconds: 500));
      expect(h.cache.requests, isEmpty);
      expect(h.api.requests, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'a stale local lookup cannot publish or launch cache/API requests',
      (tester) async {
    final firstLocal = Completer<List<Meal>>();
    var reads = 0;
    final h = await _setup(tester,
        users: _Users()
          ..respond =
              () => ++reads == 1 ? firstLocal.future : Future.value([]));
    await _start(tester, h.container, 'riz');
    h.container.read(_provider.notifier).searchFood('pomme');
    firstLocal.complete([_meal('Riz complet', '2026-11-14')]);
    await tester.pump();
    expect(h.container.read(_provider).status, SearchStatus.loading);
    expect(h.container.read(_provider).searchSuggestions, isEmpty);
    expect(h.cache.requests, isEmpty);
    h.container.read(_provider.notifier).clearSearch();
  });

  testWidgets('late expanded-search results cannot replace a new normal search',
      (tester) async {
    final pending = Completer<List<Map<String, dynamic>>>();
    final h = await _setup(tester, fatSecret: (_) => pending.future);
    final oldSearch =
        h.container.read(_provider.notifier).searchFoodFatSecret('riz');
    await _start(tester, h.container, 'pomme');
    h.cache.pending.single
        .complete(List.generate(5, (i) => _result('Pomme $i')));
    await tester.pump();
    pending.complete([_result('Riz complet')]);
    await oldSearch;
    await tester.pump();
    expect(
        h.container
            .read(_provider)
            .searchSuggestions
            .every((r) => r['product_name'].startsWith('Pomme')),
        isTrue);
  });

  testWidgets('forceOnline still works when there are enough strong results',
      (tester) async {
    final h =
        await _setup(tester, local: List.generate(5, (i) => _local('Riz $i')));
    h.container.read(_provider.notifier).searchFood('riz', forceOnline: true);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    h.cache.pending.single.complete([]);
    await tester.pump();
    expect(h.api.queries, ['riz']);
  });
}
