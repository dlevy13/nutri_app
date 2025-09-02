# nutriApp — Vue des dépendances **par dossier**
> Sous-graphes Mermaid pour `ui/`, `state/`, `providers/`, `services/`, `models/` (et `other/`).

## Diagramme
```mermaid
flowchart LR
  subgraph ui/
    N143561425["ui\/strings.dart"]
  end
  subgraph state/
  end
  subgraph providers/
    N165019143["providers\/common_providers.dart"]
  end
  subgraph services/
    N503977825["services\/ai_manager.dart"]
    N591769089["services\/ai_providers.dart"]
    N927589265["services\/ai_service.dart"]
    N100218145["services\/analysis_cache_service.dart"]
    N708047773["services\/api_config.dart"]
    N329263532["services\/auth_service.dart"]
    N458905594["services\/color_extensions.dart"]
    N956231063["services\/date_service.dart"]
    N430271319["services\/decomposition_service.dart"]
    N993238535["services\/fonctions.dart"]
    N753893858["services\/garmin_calendar_service.dart"]
    N143355252["services\/meal_database_service.dart"]
    N962913329["services\/num_safety.dart"]
    N9110089["services\/search_api_service.dart"]
    N53939559["services\/strava_service.dart"]
  end
  subgraph models/
    N253210548["models\/aliment_usuel.dart"]
    N505075974["models\/analysis.dart"]
    N592237680["models\/analysis.g.dart"]
    N819947517["models\/app_user.dart"]
    N363784393["models\/custom_food.dart"]
    N972472499["models\/daily_calories.dart"]
    N833936194["models\/meal.dart"]
    N892496057["models\/meal.g.dart"]
    N100244351["models\/proposed_ingredient.dart"]
  end
  subgraph other/
    N498262112["core\/base\/base_model.dart"]
    N501537902["core\/base\/base_service.dart"]
    N114273980["core\/base\/base_view_model.dart"]
    N343788528["core\/locator.dart"]
    N112164647["core\/logger.dart"]
    N557538589["core\/providers.dart"]
    N546385491["core\/services\/navigator_service.dart"]
    N294853191["courbe\/bej_chart.dart"]
    N823172099["courbe\/bej_providers.dart"]
    N826892258["courbe\/bej_trends_page.dart"]
    N461618427["courbe\/macro_chart.dart"]
    N406315280["courbe\/macro_providers.dart"]
    N56383445["courbe\/sat_char.dart"]
    N522857170["courbe\/sat_providers.dart"]
    N691152530["dashboard\/dashboard_notifier.dart"]
    N448753416["dashboard\/dashboard_page.dart"]
    N809779857["dashboard\/dashboard_state.dart"]
    N301678847["firebase_options.dart"]
    N51383762["log.dart"]
    N51507406["login\/login_notifier.dart"]
    N800214652["login\/login_state.dart"]
    N595244246["main.dart"]
    N698041293["meal_input\/meal_input_notifier.dart"]
    N652228060["meal_input\/meal_input_page.dart"]
    N200995489["meal_input\/meal_input_state.dart"]
    N842468204["pages\/legal_notice_page.dart"]
    N727174809["pages\/login_page.dart"]
    N523217538["pages\/meal_summary_page.dart"]
    N302657756["pages\/onboarding_page.dart"]
    N757042205["pages\/profile_form_page.dart"]
    N212588932["pages\/register_page.dart"]
    N247131344["pages\/splash_screen.dart"]
    N466667705["pages\/training_planner_page.dart"]
    N798416934["pages\/welcome_page.dart"]
    N726814518["profile_form\/profile_form_notifier.dart"]
    N650438058["profile_form\/profile_form_state.dart"]
    N603444972["register\/register_notifier.dart"]
    N816809547["register\/register_state.dart"]
    N99215588["repositories\/enrichir_poids_usuel.dart"]
    N881167038["repositories\/food_api_repository.dart"]
    N741054038["repositories\/meal_repository.dart"]
    N882877971["repositories\/strava_repository.dart"]
    N262374236["repositories\/training_repository.dart"]
    N262063898["repositories\/user_repository.dart"]
    N141351954["startup_gate.dart"]
    N406070854["training_planner\/training_planner_notifier.dart"]
    N614493050["training_planner\/training_planner_state.dart"]
    N700297013["views\/home\/home_desktop.dart"]
    N179512494["views\/home\/home_mobile.dart"]
    N121954493["views\/home\/home_tablet.dart"]
    N441139719["views\/home\/home_view.dart"]
    N908653607["views\/home\/home_view_model.dart"]
    N469652430["widget\/GarminLinkCaptureWeb.dart"]
    N333474414["widget\/added_food_tile.dart"]
    N741214780["widget\/ai_analysis_card.dart"]
    N782971607["widget\/create_food_button.dart"]
    N701384420["widget\/decomposition_review_sheet.dart"]
    N306126348["widget\/fat_breakdown_card.dart"]
    N59433925["widget\/food_list_item.dart"]
    N800851873["widget\/food_search_field.dart"]
    N634958764["widget\/quantity_page.dart"]
    N261994077["widget\/suggestion_meal_card.dart"]
  end
  N595244246 --> N343788528
  N595244246 --> N557538589
  N595244246 --> N546385491
  N595244246 --> N441139719
  N141351954 --> N302657756
  N141351954 --> N798416934
  N141351954 --> N448753416
  N343788528 --> N112164647
  N343788528 --> N546385491
  N557538589 --> N343788528
  N557538589 --> N546385491
  N501537902 --> N112164647
  N114273980 --> N112164647
  N546385491 --> N501537902
  N294853191 --> N823172099
  N294853191 --> N143561425
  N826892258 --> N294853191
  N826892258 --> N461618427
  N461618427 --> N406315280
  N691152530 --> N833936194
  N691152530 --> N741054038
  N691152530 --> N262063898
  N691152530 --> N262374236
  N691152530 --> N956231063
  N691152530 --> N882877971
  N691152530 --> N591769089
  N691152530 --> N503977825
  N691152530 --> N809779857
  N448753416 --> N652228060
  N448753416 --> N757042205
  N448753416 --> N466667705
  N448753416 --> N956231063
  N448753416 --> N882877971
  N448753416 --> N691152530
  N448753416 --> N809779857
  N448753416 --> N741214780
  N448753416 --> N306126348
  N448753416 --> N826892258
  N448753416 --> N143561425
  N809779857 --> N833936194
  N51507406 --> N800214652
  N698041293 --> N200995489
  N698041293 --> N833936194
  N698041293 --> N741054038
  N698041293 --> N956231063
  N698041293 --> N993238535
  N698041293 --> N881167038
  N698041293 --> N262063898
  N652228060 --> N833936194
  N652228060 --> N99215588
  N652228060 --> N698041293
  N652228060 --> N200995489
  N652228060 --> N800851873
  N652228060 --> N782971607
  N652228060 --> N956231063
  N652228060 --> N253210548
  N652228060 --> N430271319
  N652228060 --> N962913329
  N652228060 --> N100244351
  N652228060 --> N701384420
  N652228060 --> N634958764
  N652228060 --> N261994077
  N652228060 --> N333474414
  N200995489 --> N833936194
  N727174809 --> N51507406
  N727174809 --> N800214652
  N727174809 --> N595244246
  N523217538 --> N833936194
  N302657756 --> N798416934
  N757042205 --> N726814518
  N757042205 --> N650438058
  N757042205 --> N882877971
  N757042205 --> N469652430
  N757042205 --> N842468204
  N212588932 --> N603444972
  N212588932 --> N816809547
  N247131344 --> N448753416
  N466667705 --> N406070854
  N466667705 --> N614493050
  N798416934 --> N212588932
  N798416934 --> N727174809
  N798416934 --> N842468204
  N726814518 --> N262063898
  N726814518 --> N53939559
  N726814518 --> N650438058
  N726814518 --> N882877971
  N165019143 --> N833936194
  N165019143 --> N505075974
  N603444972 --> N816809547
  N741054038 --> N833936194
  N741054038 --> N956231063
  N741054038 --> N993238535
  N882877971 --> N53939559
  N262374236 --> N165019143
  N262063898 --> N165019143
  N262063898 --> N833936194
  N503977825 --> N956231063
  N503977825 --> N100218145
  N503977825 --> N993238535
  N503977825 --> N927589265
  N591769089 --> N503977825
  N591769089 --> N927589265
  N591769089 --> N100218145
  N100218145 --> N505075974
  N329263532 --> N819947517
  N329263532 --> N993238535
  N329263532 --> N51383762
  N993238535 --> N819947517
  N993238535 --> N833936194
  N993238535 --> N51383762
  N753893858 --> N51383762
  N143355252 --> N833936194
  N143355252 --> N51383762
  N53939559 --> N51383762
  N406070854 --> N262374236
  N406070854 --> N753893858
  N406070854 --> N614493050
  N441139719 --> N908653607
  N908653607 --> N114273980
  N333474414 --> N833936194
  N333474414 --> N993238535
  N701384420 --> N100244351
  N701384420 --> N698041293
  N306126348 --> N691152530
  N261994077 --> N833936194
  N261994077 --> N993238535
```

## Stats
```json
{
  "total_files": 88,
  "total_edges": 126,
  "folders": {
    "ui": 1,
    "state": 0,
    "providers": 1,
    "services": 15,
    "models": 9
  },
  "others": 62,
  "rendered_edges": 126
}
```