import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_app/models/meal.dart';
import 'package:nutri_app/ui/theme/app_theme.dart';
import 'package:nutri_app/widget/added_food_tile.dart';
import 'package:nutri_app/widget/food_search_field.dart';
import 'package:nutri_app/widget/food_list_item.dart';
import 'package:nutri_app/widget/meal_description_card.dart';
import 'package:nutri_app/widget/quantity_page.dart';
import 'package:nutri_app/widget/suggestion_meal_card.dart';
import 'package:nutri_app/widget/totals_bar.dart';

void main() {
  final meal = Meal(
      name: 'Pain complet aux céréales et aux graines de courge',
      calories: 210,
      protein: 8,
      carbs: 32,
      fat: 5,
      quantity: 80,
      type: 'Déjeuner',
      date: '2026-11-12');
  Widget app(Widget child, {double scale = 1, double keyboard = 0}) =>
      MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  viewInsets: EdgeInsets.only(bottom: keyboard)),
              child: child!),
          home: child);

  for (final width in [320.0, 768.0, 1280.0]) {
    testWidgets('meal components fit $width with large text', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(
          Scaffold(
              body: SingleChildScrollView(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(children: [
                        SuggestionMealCard(
                            meal: meal,
                            kcalPer100: 260,
                            proteinPer100: 10,
                            carbsPer100: 40,
                            fatPer100: 6,
                            onAdd: () {}),
                        AddedFoodTile(
                            meal: meal,
                            onRemove: () {},
                            onQtyChange: (_) {},
                            unitLabel: 'tranche épaisse',
                            unitStepGrams: 40),
                        FoodListItem(
                            title: meal.name,
                            subtitle:
                                '260 kcal / 100 g · Protéines 10 g · Glucides 40 g',
                            onTap: () {}),
                      ]))),
              bottomNavigationBar: const TotalsBar(
                  calories: 12345, prot: 123, carbs: 456, fat: 78)),
          scale: 1.6));
      expect(tester.takeException(), isNull);
    });

    testWidgets('quantity screen fits $width with large text and keyboard',
        (tester) async {
      tester.view.physicalSize = Size(width, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(
          const QuantityPage(
              title: "Quantité pour 'Pain d’épices'",
              unite: 'g',
              defaultValue: 80,
              usualUnits: [
                UsualUnit(label: 'tranche épaisse', gramsPerUnit: 40)
              ]),
          scale: 1.6,
          keyboard: 240));
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('½ portion'), 100,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('½ portion'));
      await tester.pump();
      expect(find.text('Ajouter 20 g'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'search clears and reports text; IA action requires a description',
      (tester) async {
    final search = TextEditingController();
    final description = TextEditingController();
    addTearDown(search.dispose);
    addTearDown(description.dispose);
    String query = '';
    var analyzed = false;
    await tester.pumpWidget(app(Scaffold(
        body: ListView(children: [
      FoodSearchField(
          controller: search,
          onChanged: (v) => query = v,
          onClear: () {
            search.clear();
            query = '';
          }),
      MealDescriptionCard(
          controller: description, onAnalyze: () => analyzed = true),
    ]))));
    await tester.enterText(find.byType(TextField).first, 'riz');
    expect(query, 'riz');
    await tester.pump();
    await tester.tap(find.byTooltip('Effacer la recherche'));
    expect(search.text, isEmpty);
    expect(query, isEmpty);
    await tester.tap(find.text('Décrire un plat avec l’IA'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    await tester.enterText(find.byType(TextField).last, 'Riz et poulet');
    await tester.pump();
    await tester.tap(find.text('Analyser le plat'));
    expect(analyzed, isTrue);
  });

  testWidgets(
      'quantity accepts French decimals and returns grams; rejects invalid input',
      (tester) async {
    double? result;
    await tester.pumpWidget(app(Builder(
        builder: (context) => Scaffold(
                body: TextButton(
              onPressed: () async {
                result = await Navigator.push<double>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const QuantityPage(
                            title: "Quantité pour 'Pain d'épices'",
                            unite: 'g',
                            defaultValue: 100)));
              },
              child: const Text('Ouvrir'),
            )))));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    expect(find.text("Pain d'épices"), findsOneWidget);
    for (final invalid in ['', '-2', 'NaN', 'Infinity', '1000000', '0']) {
      await tester.enterText(find.byType(TextField), invalid);
      await tester.pump();
      expect(
          tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
          isNull);
    }
    await tester.enterText(find.byType(TextField), '125,5');
    await tester.pump();
    await tester.tap(find.text('Ajouter 125.5 g'));
    await tester.pumpAndSettle();
    expect(result, 125.5);
  });

  testWidgets('food actions preserve portion steps and removal',
      (tester) async {
    double? quantity;
    var removed = false;
    var chosen = false;
    await tester.pumpWidget(app(Scaffold(
        body: ListView(children: [
      AddedFoodTile(
          meal: meal,
          unitStepGrams: 40,
          onQtyChange: (v) => quantity = v,
          onRemove: () => removed = true),
      SuggestionMealCard(
          meal: meal,
          kcalPer100: 260,
          proteinPer100: 10,
          carbsPer100: 40,
          fatPer100: 6,
          onAdd: () => chosen = true),
    ]))));
    await tester.tap(find.byTooltip('Augmenter la quantité'));
    expect(quantity, 120);
    await tester.tap(find.byTooltip('Réduire la quantité'));
    expect(quantity, 40);
    await tester.tap(find.byTooltip('Supprimer'));
    expect(removed, isTrue);
    await tester.tap(find.byType(SuggestionMealCard));
    expect(chosen, isTrue);
  });
}
