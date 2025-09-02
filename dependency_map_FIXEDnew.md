# nutriApp — Carte complète des dépendances (FIXED)
> Basée sur les imports réels dans `lib/` et résolue via `pubspec.yaml`.

## Résumé
```json
{
  "files": 88,
  "imports": 126,
  "pages": 28,
  "providers": 18,
  "notifiers": 6,
  "repositories": 6,
  "models": 2,
  "uses_firestore": 17,
  "uses_hive": 5,
  "uses_prefs": 8
}
```

## 1) Graphe global des imports
```mermaid
flowchart LR
  subgraph DATASRC[Sources]
    HIVE[(Hive)]
    FIRESTORE[(Firestore)]
    PREFS[(SharedPreferences)]
  end
  N9947517["models\/app_user.dart"]
  N3217538["pages\/meal_summary_page.dart"]:::page
  N214652["login\/login_state.dart"]
  N1618427["courbe\/macro_chart.dart"]
  N4493050["training_planner\/training_planner_state.dart"]
  N3238535["services\/fonctions.dart"]
  N3238535 --- FIRESTORE
  N3238535 --- PREFS
  N8753416["dashboard\/dashboard_page.dart"]:::page
  N8753416 --- FIRESTORE
  N3788528["core\/locator.dart"]
  N7589265["services\/ai_service.dart"]
  N1537902["core\/base\/base_service.dart"]
  N1152530["dashboard\/dashboard_notifier.dart"]:::vm
  N1152530 --- FIRESTORE
  N3474414["widget\/added_food_tile.dart"]:::page
  N7174809["pages\/login_page.dart"]:::page
  N9215588["repositories\/enrichir_poids_usuel.dart"]:::repo
  N9215588 --- FIRESTORE
  N7538589["core\/providers.dart"]:::vm
  N1384420["widget\/decomposition_review_sheet.dart"]:::page
  N3893858["services\/garmin_calendar_service.dart"]
  N3893858 --- FIRESTORE
  N3893858 --- PREFS
  N851873["widget\/food_search_field.dart"]:::page
  N2374236["repositories\/training_repository.dart"]:::vm
  N2374236 --- PREFS
  N8416934["pages\/welcome_page.dart"]:::page
  N2164647["core\/logger.dart"]
  N244351["models\/proposed_ingredient.dart"]
  N1054038["repositories\/meal_repository.dart"]:::vm
  N1054038 --- FIRESTORE
  N438058["profile_form\/profile_form_state.dart"]
  N4958764["widget\/quantity_page.dart"]:::page
  N6385491["core\/services\/navigator_service.dart"]
  N9263532["services\/auth_service.dart"]
  N9263532 --- FIRESTORE
  N1383762["log.dart"]
  N9652430["widget\/GarminLinkCaptureWeb.dart"]:::page
  N8041293["meal_input\/meal_input_notifier.dart"]:::vm
  N3210548["models\/aliment_usuel.dart"]
  N6809547["register\/register_state.dart"]
  N4273980["core\/base\/base_view_model.dart"]
  N3936194["models\/meal.dart"]:::model
  N3936194 --- HIVE
  N1167038["repositories\/food_api_repository.dart"]:::vm
  N1214780["widget\/ai_analysis_card.dart"]:::page
  N6070854["training_planner\/training_planner_notifier.dart"]:::vm
  N4853191["courbe\/bej_chart.dart"]
  N6667705["pages\/training_planner_page.dart"]:::page
  N6814518["profile_form\/profile_form_notifier.dart"]:::vm
  N5019143["providers\/common_providers.dart"]:::vm
  N5019143 --- HIVE
  N5019143 --- PREFS
  N1507406["login\/login_notifier.dart"]:::vm
  N2913329["services\/num_safety.dart"]
  N7131344["pages\/splash_screen.dart"]:::page
  N3561425["ui\/strings.dart"]
  N5244246["main.dart"]:::page
  N2971607["widget\/create_food_button.dart"]:::page
  N271319["services\/decomposition_service.dart"]
  N8653607["views\/home\/home_view_model.dart"]
  N2657756["pages\/onboarding_page.dart"]:::page
  N2657756 --- PREFS
  N2228060["meal_input\/meal_input_page.dart"]:::page
  N1994077["widget\/suggestion_meal_card.dart"]:::page
  N995489["meal_input\/meal_input_state.dart"]
  N218145["services\/analysis_cache_service.dart"]
  N218145 --- HIVE
  N218145 --- FIRESTORE
  N3977825["services\/ai_manager.dart"]
  N6892258["courbe\/bej_trends_page.dart"]:::page
  N7042205["pages\/profile_form_page.dart"]:::page
  N2063898["repositories\/user_repository.dart"]:::vm
  N2063898 --- FIRESTORE
  N2063898 --- PREFS
  N3939559["services\/strava_service.dart"]
  N3939559 --- FIRESTORE
  N3939559 --- PREFS
  N6231063["services\/date_service.dart"]
  N2468204["pages\/legal_notice_page.dart"]:::page
  N2877971["repositories\/strava_repository.dart"]:::vm
  N2877971 --- FIRESTORE
  N1351954["startup_gate.dart"]:::page
  N1351954 --- FIRESTORE
  N1351954 --- PREFS
  N9779857["dashboard\/dashboard_state.dart"]
  N6315280["courbe\/macro_providers.dart"]:::vm
  N6315280 --- FIRESTORE
  N3444972["register\/register_notifier.dart"]:::vm
  N3444972 --- FIRESTORE
  N6126348["widget\/fat_breakdown_card.dart"]:::page
  N3355252["services\/meal_database_service.dart"]
  N3355252 --- HIVE
  N3355252 --- FIRESTORE
  N1139719["views\/home\/home_view.dart"]:::page
  N5075974["models\/analysis.dart"]:::model
  N5075974 --- HIVE
  N2588932["pages\/register_page.dart"]:::page
  N3172099["courbe\/bej_providers.dart"]:::vm
  N3172099 --- FIRESTORE
  N1769089["services\/ai_providers.dart"]:::vm
  N5244246 --> N3788528
  N5244246 --> N7538589
  N5244246 --> N6385491
  N5244246 --> N1139719
  N1351954 --> N2657756
  N1351954 --> N8416934
  N1351954 --> N8753416
  N3788528 --> N2164647
  N3788528 --> N6385491
  N7538589 --> N3788528
  N7538589 --> N6385491
  N1537902 --> N2164647
  N4273980 --> N2164647
  N6385491 --> N1537902
  N4853191 --> N3172099
  N4853191 --> N3561425
  N6892258 --> N4853191
  N6892258 --> N1618427
  N1618427 --> N6315280
  N1152530 --> N3936194
  N1152530 --> N1054038
  N1152530 --> N2063898
  N1152530 --> N2374236
  N1152530 --> N6231063
  N1152530 --> N2877971
  N1152530 --> N1769089
  N1152530 --> N3977825
  N1152530 --> N9779857
  N8753416 --> N2228060
  N8753416 --> N7042205
  N8753416 --> N6667705
  N8753416 --> N6231063
  N8753416 --> N2877971
  N8753416 --> N1152530
  N8753416 --> N9779857
  N8753416 --> N1214780
  N8753416 --> N6126348
  N8753416 --> N6892258
  N8753416 --> N3561425
  N9779857 --> N3936194
  N1507406 --> N214652
  N8041293 --> N995489
  N8041293 --> N3936194
  N8041293 --> N1054038
  N8041293 --> N6231063
  N8041293 --> N3238535
  N8041293 --> N1167038
  N8041293 --> N2063898
  N2228060 --> N3936194
  N2228060 --> N9215588
  N2228060 --> N8041293
  N2228060 --> N995489
  N2228060 --> N851873
  N2228060 --> N2971607
  N2228060 --> N6231063
  N2228060 --> N3210548
  N2228060 --> N271319
  N2228060 --> N2913329
  N2228060 --> N244351
  N2228060 --> N1384420
  N2228060 --> N4958764
  N2228060 --> N1994077
  N2228060 --> N3474414
  N995489 --> N3936194
  N7174809 --> N1507406
  N7174809 --> N214652
  N7174809 --> N5244246
  N3217538 --> N3936194
  N2657756 --> N8416934
  N7042205 --> N6814518
  N7042205 --> N438058
  N7042205 --> N2877971
  N7042205 --> N9652430
  N7042205 --> N2468204
  N2588932 --> N3444972
  N2588932 --> N6809547
  N7131344 --> N8753416
  N6667705 --> N6070854
  N6667705 --> N4493050
  N8416934 --> N2588932
  N8416934 --> N7174809
  N8416934 --> N2468204
  N6814518 --> N2063898
  N6814518 --> N3939559
  N6814518 --> N438058
  N6814518 --> N2877971
  N5019143 --> N3936194
  N5019143 --> N5075974
  N3444972 --> N6809547
  N1054038 --> N3936194
  N1054038 --> N6231063
  N1054038 --> N3238535
  N2877971 --> N3939559
  N2374236 --> N5019143
  N2063898 --> N5019143
  N2063898 --> N3936194
  N3977825 --> N6231063
  N3977825 --> N218145
  N3977825 --> N3238535
  N3977825 --> N7589265
  N1769089 --> N3977825
  N1769089 --> N7589265
  N1769089 --> N218145
  N218145 --> N5075974
  N9263532 --> N9947517
  N9263532 --> N3238535
  N9263532 --> N1383762
  N3238535 --> N9947517
  N3238535 --> N3936194
  N3238535 --> N1383762
  N3893858 --> N1383762
  N3355252 --> N3936194
  N3355252 --> N1383762
  N3939559 --> N1383762
  N6070854 --> N2374236
  N6070854 --> N3893858
  N6070854 --> N4493050
  N1139719 --> N8653607
  N8653607 --> N4273980
  N3474414 --> N3936194
  N3474414 --> N3238535
  N1384420 --> N244351
  N1384420 --> N8041293
  N6126348 --> N1152530
  N1994077 --> N3936194
  N1994077 --> N3238535
classDef page fill:#fff,stroke:#888,stroke-width:1px;
classDef vm fill:#eef7ff,stroke:#3b82f6,stroke-width:1px;
classDef repo fill:#fff7ed,stroke:#f59e0b,stroke-width:1px;
classDef model fill:#f0fdf4,stroke:#22c55e,stroke-width:1px;
```

## 2) Vue focalisée (Pages/Providers/Notifiers → Repositories/Models)
```mermaid
flowchart LR
  subgraph DATASRC[Sources]
    HIVE[(Hive)]
    FIRESTORE[(Firestore)]
    PREFS[(SharedPreferences)]
  end
  N3217538["pages\/meal_summary_page.dart"]:::page
  N8753416["dashboard\/dashboard_page.dart"]:::page
  N8753416 --- FIRESTORE
  N1152530["dashboard\/dashboard_notifier.dart"]:::vm
  N1152530 --- FIRESTORE
  N3474414["widget\/added_food_tile.dart"]:::page
  N9215588["repositories\/enrichir_poids_usuel.dart"]:::repo
  N9215588 --- FIRESTORE
  N2374236["repositories\/training_repository.dart"]:::vm
  N2374236 --- PREFS
  N1054038["repositories\/meal_repository.dart"]:::vm
  N1054038 --- FIRESTORE
  N8041293["meal_input\/meal_input_notifier.dart"]:::vm
  N1167038["repositories\/food_api_repository.dart"]:::vm
  N3936194["models\/meal.dart"]:::model
  N3936194 --- HIVE
  N6070854["training_planner\/training_planner_notifier.dart"]:::vm
  N6814518["profile_form\/profile_form_notifier.dart"]:::vm
  N2228060["meal_input\/meal_input_page.dart"]:::page
  N1994077["widget\/suggestion_meal_card.dart"]:::page
  N7042205["pages\/profile_form_page.dart"]:::page
  N2063898["repositories\/user_repository.dart"]:::vm
  N2063898 --- FIRESTORE
  N2063898 --- PREFS
  N2877971["repositories\/strava_repository.dart"]:::vm
  N2877971 --- FIRESTORE
  N5019143["providers\/common_providers.dart"]:::vm
  N5019143 --- HIVE
  N5019143 --- PREFS
  N5075974["models\/analysis.dart"]:::model
  N5075974 --- HIVE
  N1152530 --> N3936194
  N1152530 --> N1054038
  N1152530 --> N2063898
  N1152530 --> N2374236
  N1152530 --> N2877971
  N8753416 --> N2877971
  N8041293 --> N3936194
  N8041293 --> N1054038
  N8041293 --> N1167038
  N8041293 --> N2063898
  N2228060 --> N3936194
  N2228060 --> N9215588
  N3217538 --> N3936194
  N7042205 --> N2877971
  N6814518 --> N2063898
  N6814518 --> N2877971
  N5019143 --> N3936194
  N5019143 --> N5075974
  N1054038 --> N3936194
  N2063898 --> N3936194
  N6070854 --> N2374236
  N3474414 --> N3936194
  N1994077 --> N3936194
classDef page fill:#fff,stroke:#888,stroke-width:1px;
classDef vm fill:#eef7ff,stroke:#3b82f6,stroke-width:1px;
classDef repo fill:#fff7ed,stroke:#f59e0b,stroke-width:1px;
classDef model fill:#f0fdf4,stroke:#22c55e,stroke-width:1px;
```

## 3) Liaisons directes Notifiers/Providers → Repositories
```mermaid
flowchart LR
  subgraph DATASRC[Sources]
    HIVE[(Hive)]
    FIRESTORE[(Firestore)]
    PREFS[(SharedPreferences)]
  end
  N2374236["repositories\/training_repository.dart"]:::vm
  N2374236 --- PREFS
  N2063898["repositories\/user_repository.dart"]:::vm
  N2063898 --- FIRESTORE
  N2063898 --- PREFS
  N6070854["training_planner\/training_planner_notifier.dart"]:::vm
  N8753416["dashboard\/dashboard_page.dart"]:::page
  N8753416 --- FIRESTORE
  N1054038["repositories\/meal_repository.dart"]:::vm
  N1054038 --- FIRESTORE
  N6814518["profile_form\/profile_form_notifier.dart"]:::vm
  N2877971["repositories\/strava_repository.dart"]:::vm
  N2877971 --- FIRESTORE
  N1152530["dashboard\/dashboard_notifier.dart"]:::vm
  N1152530 --- FIRESTORE
  N8041293["meal_input\/meal_input_notifier.dart"]:::vm
  N1167038["repositories\/food_api_repository.dart"]:::vm
  N1152530 --> N1054038
  N1152530 --> N2063898
  N1152530 --> N2374236
  N1152530 --> N2877971
  N8753416 --> N2877971
  N8041293 --> N1054038
  N8041293 --> N1167038
  N8041293 --> N2063898
  N6814518 --> N2063898
  N6814518 --> N2877971
  N6070854 --> N2374236
classDef page fill:#fff,stroke:#888,stroke-width:1px;
classDef vm fill:#eef7ff,stroke:#3b82f6,stroke-width:1px;
classDef repo fill:#fff7ed,stroke:#f59e0b,stroke-width:1px;
classDef model fill:#f0fdf4,stroke:#22c55e,stroke-width:1px;
```

## 4) Dépendances entre dossiers
```mermaid
flowchart LR
  F2653726["."]
  F4235064["core"]
  F3298879["courbe"]
  F2034301["dashboard"]
  F2389116["login"]
  F5754208["meal_input"]
  F5027062["models"]
  F8590911["pages"]
  F7322961["profile_form"]
  F9724584["providers"]
  F5101274["register"]
  F2121628["repositories"]
  F8406552["services"]
  F6926181["training_planner"]
  F3561637["ui"]
  F9671952["views"]
  F5039631["widget"]
  F2653726 --> F4235064
  F2653726 --> F2034301
  F2653726 --> F8590911
  F2653726 --> F9671952
  F3298879 --> F3561637
  F2034301 --> F3298879
  F2034301 --> F5754208
  F2034301 --> F5027062
  F2034301 --> F8590911
  F2034301 --> F2121628
  F2034301 --> F8406552
  F2034301 --> F3561637
  F2034301 --> F5039631
  F5754208 --> F5027062
  F5754208 --> F2121628
  F5754208 --> F8406552
  F5754208 --> F5039631
  F8590911 --> F2653726
  F8590911 --> F2034301
  F8590911 --> F2389116
  F8590911 --> F5027062
  F8590911 --> F7322961
  F8590911 --> F5101274
  F8590911 --> F2121628
  F8590911 --> F6926181
  F8590911 --> F5039631
  F7322961 --> F2121628
  F7322961 --> F8406552
  F9724584 --> F5027062
  F2121628 --> F5027062
  F2121628 --> F9724584
  F2121628 --> F8406552
  F8406552 --> F2653726
  F8406552 --> F5027062
  F6926181 --> F2121628
  F6926181 --> F8406552
  F9671952 --> F4235064
  F5039631 --> F2034301
  F5039631 --> F5754208
  F5039631 --> F5027062
  F5039631 --> F8406552
```

## 5) Exports JSON (fichiers & imports)
```json
{
  "nodes": {
    "firebase_options.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": true,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "log.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "main.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": true,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "core/locator.dart",
        "core/providers.dart",
        "core/services/navigator_service.dart",
        "views/home/home_view.dart"
      ]
    },
    "startup_gate.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": true,
        "model": false,
        "uses_firestore": true,
        "uses_hive": false,
        "uses_prefs": true
      },
      "imports": [
        "pages/onboarding_page.dart",
        "pages/welcome_page.dart",
        "dashboard/dashboard_page.dart"
      ]
    },
    "core/locator.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "core/logger.dart",
        "core/services/navigator_service.dart"
      ]
    },
    "core/logger.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "core/providers.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": true,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "core/locator.dart",
        "core/services/navigator_service.dart"
      ]
    },
    "core/base/base_model.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "core/base/base_service.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "core/logger.dart"
      ]
    },
    "core/base/base_view_model.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "core/logger.dart"
      ]
    },
    "core/services/navigator_service.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "core/base/base_service.dart"
      ]
    },
    "courbe/bej_chart.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "courbe/bej_providers.dart",
        "ui/strings.dart"
      ]
    },
    "courbe/bej_providers.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": true,
        "page": false,
        "model": false,
        "uses_firestore": true,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "courbe/bej_trends_page.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": true,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "courbe/bej_chart.dart",
        "courbe/macro_chart.dart"
      ]
    },
    "courbe/macro_chart.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "courbe/macro_providers.dart"
      ]
    },
    "courbe/macro_providers.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": true,
        "page": false,
        "model": false,
        "uses_firestore": true,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "courbe/sat_char.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "courbe/sat_providers.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": true,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "dashboard/dashboard_notifier.dart": {
      "flags": {
        "notifier": true,
        "repository": false,
        "provider": true,
        "page": false,
        "model": false,
        "uses_firestore": true,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "models/meal.dart",
        "repositories/meal_repository.dart",
        "repositories/user_repository.dart",
        "repositories/training_repository.dart",
        "services/date_service.dart",
        "repositories/strava_repository.dart",
        "services/ai_providers.dart",
        "services/ai_manager.dart",
        "dashboard/dashboard_state.dart"
      ]
    },
    "dashboard/dashboard_page.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": true,
        "page": true,
        "model": false,
        "uses_firestore": true,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "meal_input/meal_input_page.dart",
        "pages/profile_form_page.dart",
        "pages/training_planner_page.dart",
        "services/date_service.dart",
        "repositories/strava_repository.dart",
        "dashboard/dashboard_notifier.dart",
        "dashboard/dashboard_state.dart",
        "widget/ai_analysis_card.dart",
        "widget/fat_breakdown_card.dart",
        "courbe/bej_trends_page.dart",
        "ui/strings.dart"
      ]
    },
    "dashboard/dashboard_state.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "models/meal.dart"
      ]
    },
    "login/login_notifier.dart": {
      "flags": {
        "notifier": true,
        "repository": false,
        "provider": true,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "login/login_state.dart"
      ]
    },
    "login/login_state.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "meal_input/meal_input_notifier.dart": {
      "flags": {
        "notifier": true,
        "repository": false,
        "provider": true,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "meal_input/meal_input_state.dart",
        "models/meal.dart",
        "repositories/meal_repository.dart",
        "services/date_service.dart",
        "services/fonctions.dart",
        "repositories/food_api_repository.dart",
        "repositories/user_repository.dart"
      ]
    },
    "meal_input/meal_input_page.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": true,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "models/meal.dart",
        "repositories/enrichir_poids_usuel.dart",
        "meal_input/meal_input_notifier.dart",
        "meal_input/meal_input_state.dart",
        "widget/food_search_field.dart",
        "widget/create_food_button.dart",
        "services/date_service.dart",
        "models/aliment_usuel.dart",
        "services/decomposition_service.dart",
        "services/num_safety.dart",
        "models/proposed_ingredient.dart",
        "widget/decomposition_review_sheet.dart",
        "widget/quantity_page.dart",
        "widget/suggestion_meal_card.dart",
        "widget/added_food_tile.dart"
      ]
    },
    "meal_input/meal_input_state.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "models/meal.dart"
      ]
    },
    "models/aliment_usuel.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "models/analysis.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": true,
        "uses_firestore": false,
        "uses_hive": true,
        "uses_prefs": false
      },
      "imports": []
    },
    "models/analysis.g.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "models/app_user.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "models/custom_food.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "models/daily_calories.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "models/meal.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": true,
        "uses_firestore": false,
        "uses_hive": true,
        "uses_prefs": false
      },
      "imports": []
    },
    "models/meal.g.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "models/proposed_ingredient.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "pages/legal_notice_page.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": true,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "pages/login_page.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": true,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "login/login_notifier.dart",
        "login/login_state.dart",
        "main.dart"
      ]
    },
    "pages/meal_summary_page.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": true,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "models/meal.dart"
      ]
    },
    "pages/onboarding_page.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": true,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": true
      },
      "imports": [
        "pages/welcome_page.dart"
      ]
    },
    "pages/profile_form_page.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": true,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "profile_form/profile_form_notifier.dart",
        "profile_form/profile_form_state.dart",
        "repositories/strava_repository.dart",
        "widget/GarminLinkCaptureWeb.dart",
        "pages/legal_notice_page.dart"
      ]
    },
    "pages/register_page.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": true,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "register/register_notifier.dart",
        "register/register_state.dart"
      ]
    },
    "pages/splash_screen.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": true,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "dashboard/dashboard_page.dart"
      ]
    },
    "pages/training_planner_page.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": true,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "training_planner/training_planner_notifier.dart",
        "training_planner/training_planner_state.dart"
      ]
    },
    "pages/welcome_page.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": true,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "pages/register_page.dart",
        "pages/login_page.dart",
        "pages/legal_notice_page.dart"
      ]
    },
    "profile_form/profile_form_notifier.dart": {
      "flags": {
        "notifier": true,
        "repository": false,
        "provider": true,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "repositories/user_repository.dart",
        "services/strava_service.dart",
        "profile_form/profile_form_state.dart",
        "repositories/strava_repository.dart"
      ]
    },
    "profile_form/profile_form_state.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "providers/common_providers.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": true,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": true,
        "uses_prefs": true
      },
      "imports": [
        "models/meal.dart",
        "models/analysis.dart"
      ]
    },
    "register/register_notifier.dart": {
      "flags": {
        "notifier": true,
        "repository": false,
        "provider": true,
        "page": false,
        "model": false,
        "uses_firestore": true,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "register/register_state.dart"
      ]
    },
    "register/register_state.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "repositories/enrichir_poids_usuel.dart": {
      "flags": {
        "notifier": false,
        "repository": true,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": true,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "repositories/food_api_repository.dart": {
      "flags": {
        "notifier": false,
        "repository": true,
        "provider": true,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "repositories/meal_repository.dart": {
      "flags": {
        "notifier": false,
        "repository": true,
        "provider": true,
        "page": false,
        "model": false,
        "uses_firestore": true,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "models/meal.dart",
        "services/date_service.dart",
        "services/fonctions.dart"
      ]
    },
    "repositories/strava_repository.dart": {
      "flags": {
        "notifier": false,
        "repository": true,
        "provider": true,
        "page": false,
        "model": false,
        "uses_firestore": true,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "services/strava_service.dart"
      ]
    },
    "repositories/training_repository.dart": {
      "flags": {
        "notifier": false,
        "repository": true,
        "provider": true,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": true
      },
      "imports": [
        "providers/common_providers.dart"
      ]
    },
    "repositories/user_repository.dart": {
      "flags": {
        "notifier": false,
        "repository": true,
        "provider": true,
        "page": false,
        "model": false,
        "uses_firestore": true,
        "uses_hive": false,
        "uses_prefs": true
      },
      "imports": [
        "providers/common_providers.dart",
        "models/meal.dart"
      ]
    },
    "services/ai_manager.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "services/date_service.dart",
        "services/analysis_cache_service.dart",
        "services/fonctions.dart",
        "services/ai_service.dart"
      ]
    },
    "services/ai_providers.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": true,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "services/ai_manager.dart",
        "services/ai_service.dart",
        "services/analysis_cache_service.dart"
      ]
    },
    "services/ai_service.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "services/analysis_cache_service.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": true,
        "uses_hive": true,
        "uses_prefs": false
      },
      "imports": [
        "models/analysis.dart"
      ]
    },
    "services/api_config.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "services/auth_service.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": true,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "models/app_user.dart",
        "services/fonctions.dart",
        "log.dart"
      ]
    },
    "services/color_extensions.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "services/date_service.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "services/decomposition_service.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "services/fonctions.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": true,
        "uses_hive": false,
        "uses_prefs": true
      },
      "imports": [
        "models/app_user.dart",
        "models/meal.dart",
        "log.dart"
      ]
    },
    "services/garmin_calendar_service.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": true,
        "uses_hive": false,
        "uses_prefs": true
      },
      "imports": [
        "log.dart"
      ]
    },
    "services/meal_database_service.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": true,
        "uses_hive": true,
        "uses_prefs": false
      },
      "imports": [
        "models/meal.dart",
        "log.dart"
      ]
    },
    "services/num_safety.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "services/search_api_service.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "services/strava_service.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": true,
        "uses_hive": false,
        "uses_prefs": true
      },
      "imports": [
        "log.dart"
      ]
    },
    "training_planner/training_planner_notifier.dart": {
      "flags": {
        "notifier": true,
        "repository": false,
        "provider": true,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "repositories/training_repository.dart",
        "services/garmin_calendar_service.dart",
        "training_planner/training_planner_state.dart"
      ]
    },
    "training_planner/training_planner_state.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "ui/strings.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "views/home/home_desktop.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": true,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "views/home/home_mobile.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": true,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "views/home/home_tablet.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": true,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "views/home/home_view.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": true,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "views/home/home_view_model.dart"
      ]
    },
    "views/home/home_view_model.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": false,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "core/base/base_view_model.dart"
      ]
    },
    "widget/added_food_tile.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": true,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "models/meal.dart",
        "services/fonctions.dart"
      ]
    },
    "widget/ai_analysis_card.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": true,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "widget/create_food_button.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": true,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "widget/decomposition_review_sheet.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": true,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "models/proposed_ingredient.dart",
        "meal_input/meal_input_notifier.dart"
      ]
    },
    "widget/fat_breakdown_card.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": true,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "dashboard/dashboard_notifier.dart"
      ]
    },
    "widget/food_list_item.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": true,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "widget/food_search_field.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": true,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "widget/GarminLinkCaptureWeb.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": true,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "widget/quantity_page.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": true,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": []
    },
    "widget/suggestion_meal_card.dart": {
      "flags": {
        "notifier": false,
        "repository": false,
        "provider": false,
        "page": true,
        "model": false,
        "uses_firestore": false,
        "uses_hive": false,
        "uses_prefs": false
      },
      "imports": [
        "models/meal.dart",
        "services/fonctions.dart"
      ]
    }
  },
  "edges": [
    [
      "main.dart",
      "core/locator.dart"
    ],
    [
      "main.dart",
      "core/providers.dart"
    ],
    [
      "main.dart",
      "core/services/navigator_service.dart"
    ],
    [
      "main.dart",
      "views/home/home_view.dart"
    ],
    [
      "startup_gate.dart",
      "pages/onboarding_page.dart"
    ],
    [
      "startup_gate.dart",
      "pages/welcome_page.dart"
    ],
    [
      "startup_gate.dart",
      "dashboard/dashboard_page.dart"
    ],
    [
      "core/locator.dart",
      "core/logger.dart"
    ],
    [
      "core/locator.dart",
      "core/services/navigator_service.dart"
    ],
    [
      "core/providers.dart",
      "core/locator.dart"
    ],
    [
      "core/providers.dart",
      "core/services/navigator_service.dart"
    ],
    [
      "core/base/base_service.dart",
      "core/logger.dart"
    ],
    [
      "core/base/base_view_model.dart",
      "core/logger.dart"
    ],
    [
      "core/services/navigator_service.dart",
      "core/base/base_service.dart"
    ],
    [
      "courbe/bej_chart.dart",
      "courbe/bej_providers.dart"
    ],
    [
      "courbe/bej_chart.dart",
      "ui/strings.dart"
    ],
    [
      "courbe/bej_trends_page.dart",
      "courbe/bej_chart.dart"
    ],
    [
      "courbe/bej_trends_page.dart",
      "courbe/macro_chart.dart"
    ],
    [
      "courbe/macro_chart.dart",
      "courbe/macro_providers.dart"
    ],
    [
      "dashboard/dashboard_notifier.dart",
      "models/meal.dart"
    ],
    [
      "dashboard/dashboard_notifier.dart",
      "repositories/meal_repository.dart"
    ],
    [
      "dashboard/dashboard_notifier.dart",
      "repositories/user_repository.dart"
    ],
    [
      "dashboard/dashboard_notifier.dart",
      "repositories/training_repository.dart"
    ],
    [
      "dashboard/dashboard_notifier.dart",
      "services/date_service.dart"
    ],
    [
      "dashboard/dashboard_notifier.dart",
      "repositories/strava_repository.dart"
    ],
    [
      "dashboard/dashboard_notifier.dart",
      "services/ai_providers.dart"
    ],
    [
      "dashboard/dashboard_notifier.dart",
      "services/ai_manager.dart"
    ],
    [
      "dashboard/dashboard_notifier.dart",
      "dashboard/dashboard_state.dart"
    ],
    [
      "dashboard/dashboard_page.dart",
      "meal_input/meal_input_page.dart"
    ],
    [
      "dashboard/dashboard_page.dart",
      "pages/profile_form_page.dart"
    ],
    [
      "dashboard/dashboard_page.dart",
      "pages/training_planner_page.dart"
    ],
    [
      "dashboard/dashboard_page.dart",
      "services/date_service.dart"
    ],
    [
      "dashboard/dashboard_page.dart",
      "repositories/strava_repository.dart"
    ],
    [
      "dashboard/dashboard_page.dart",
      "dashboard/dashboard_notifier.dart"
    ],
    [
      "dashboard/dashboard_page.dart",
      "dashboard/dashboard_state.dart"
    ],
    [
      "dashboard/dashboard_page.dart",
      "widget/ai_analysis_card.dart"
    ],
    [
      "dashboard/dashboard_page.dart",
      "widget/fat_breakdown_card.dart"
    ],
    [
      "dashboard/dashboard_page.dart",
      "courbe/bej_trends_page.dart"
    ],
    [
      "dashboard/dashboard_page.dart",
      "ui/strings.dart"
    ],
    [
      "dashboard/dashboard_state.dart",
      "models/meal.dart"
    ],
    [
      "login/login_notifier.dart",
      "login/login_state.dart"
    ],
    [
      "meal_input/meal_input_notifier.dart",
      "meal_input/meal_input_state.dart"
    ],
    [
      "meal_input/meal_input_notifier.dart",
      "models/meal.dart"
    ],
    [
      "meal_input/meal_input_notifier.dart",
      "repositories/meal_repository.dart"
    ],
    [
      "meal_input/meal_input_notifier.dart",
      "services/date_service.dart"
    ],
    [
      "meal_input/meal_input_notifier.dart",
      "services/fonctions.dart"
    ],
    [
      "meal_input/meal_input_notifier.dart",
      "repositories/food_api_repository.dart"
    ],
    [
      "meal_input/meal_input_notifier.dart",
      "repositories/user_repository.dart"
    ],
    [
      "meal_input/meal_input_page.dart",
      "models/meal.dart"
    ],
    [
      "meal_input/meal_input_page.dart",
      "repositories/enrichir_poids_usuel.dart"
    ],
    [
      "meal_input/meal_input_page.dart",
      "meal_input/meal_input_notifier.dart"
    ],
    [
      "meal_input/meal_input_page.dart",
      "meal_input/meal_input_state.dart"
    ],
    [
      "meal_input/meal_input_page.dart",
      "widget/food_search_field.dart"
    ],
    [
      "meal_input/meal_input_page.dart",
      "widget/create_food_button.dart"
    ],
    [
      "meal_input/meal_input_page.dart",
      "services/date_service.dart"
    ],
    [
      "meal_input/meal_input_page.dart",
      "models/aliment_usuel.dart"
    ],
    [
      "meal_input/meal_input_page.dart",
      "services/decomposition_service.dart"
    ],
    [
      "meal_input/meal_input_page.dart",
      "services/num_safety.dart"
    ],
    [
      "meal_input/meal_input_page.dart",
      "models/proposed_ingredient.dart"
    ],
    [
      "meal_input/meal_input_page.dart",
      "widget/decomposition_review_sheet.dart"
    ],
    [
      "meal_input/meal_input_page.dart",
      "widget/quantity_page.dart"
    ],
    [
      "meal_input/meal_input_page.dart",
      "widget/suggestion_meal_card.dart"
    ],
    [
      "meal_input/meal_input_page.dart",
      "widget/added_food_tile.dart"
    ],
    [
      "meal_input/meal_input_state.dart",
      "models/meal.dart"
    ],
    [
      "pages/login_page.dart",
      "login/login_notifier.dart"
    ],
    [
      "pages/login_page.dart",
      "login/login_state.dart"
    ],
    [
      "pages/login_page.dart",
      "main.dart"
    ],
    [
      "pages/meal_summary_page.dart",
      "models/meal.dart"
    ],
    [
      "pages/onboarding_page.dart",
      "pages/welcome_page.dart"
    ],
    [
      "pages/profile_form_page.dart",
      "profile_form/profile_form_notifier.dart"
    ],
    [
      "pages/profile_form_page.dart",
      "profile_form/profile_form_state.dart"
    ],
    [
      "pages/profile_form_page.dart",
      "repositories/strava_repository.dart"
    ],
    [
      "pages/profile_form_page.dart",
      "widget/GarminLinkCaptureWeb.dart"
    ],
    [
      "pages/profile_form_page.dart",
      "pages/legal_notice_page.dart"
    ],
    [
      "pages/register_page.dart",
      "register/register_notifier.dart"
    ],
    [
      "pages/register_page.dart",
      "register/register_state.dart"
    ],
    [
      "pages/splash_screen.dart",
      "dashboard/dashboard_page.dart"
    ],
    [
      "pages/training_planner_page.dart",
      "training_planner/training_planner_notifier.dart"
    ],
    [
      "pages/training_planner_page.dart",
      "training_planner/training_planner_state.dart"
    ],
    [
      "pages/welcome_page.dart",
      "pages/register_page.dart"
    ],
    [
      "pages/welcome_page.dart",
      "pages/login_page.dart"
    ],
    [
      "pages/welcome_page.dart",
      "pages/legal_notice_page.dart"
    ],
    [
      "profile_form/profile_form_notifier.dart",
      "repositories/user_repository.dart"
    ],
    [
      "profile_form/profile_form_notifier.dart",
      "services/strava_service.dart"
    ],
    [
      "profile_form/profile_form_notifier.dart",
      "profile_form/profile_form_state.dart"
    ],
    [
      "profile_form/profile_form_notifier.dart",
      "repositories/strava_repository.dart"
    ],
    [
      "providers/common_providers.dart",
      "models/meal.dart"
    ],
    [
      "providers/common_providers.dart",
      "models/analysis.dart"
    ],
    [
      "register/register_notifier.dart",
      "register/register_state.dart"
    ],
    [
      "repositories/meal_repository.dart",
      "models/meal.dart"
    ],
    [
      "repositories/meal_repository.dart",
      "services/date_service.dart"
    ],
    [
      "repositories/meal_repository.dart",
      "services/fonctions.dart"
    ],
    [
      "repositories/strava_repository.dart",
      "services/strava_service.dart"
    ],
    [
      "repositories/training_repository.dart",
      "providers/common_providers.dart"
    ],
    [
      "repositories/user_repository.dart",
      "providers/common_providers.dart"
    ],
    [
      "repositories/user_repository.dart",
      "models/meal.dart"
    ],
    [
      "services/ai_manager.dart",
      "services/date_service.dart"
    ],
    [
      "services/ai_manager.dart",
      "services/analysis_cache_service.dart"
    ],
    [
      "services/ai_manager.dart",
      "services/fonctions.dart"
    ],
    [
      "services/ai_manager.dart",
      "services/ai_service.dart"
    ],
    [
      "services/ai_providers.dart",
      "services/ai_manager.dart"
    ],
    [
      "services/ai_providers.dart",
      "services/ai_service.dart"
    ],
    [
      "services/ai_providers.dart",
      "services/analysis_cache_service.dart"
    ],
    [
      "services/analysis_cache_service.dart",
      "models/analysis.dart"
    ],
    [
      "services/auth_service.dart",
      "models/app_user.dart"
    ],
    [
      "services/auth_service.dart",
      "services/fonctions.dart"
    ],
    [
      "services/auth_service.dart",
      "log.dart"
    ],
    [
      "services/fonctions.dart",
      "models/app_user.dart"
    ],
    [
      "services/fonctions.dart",
      "models/meal.dart"
    ],
    [
      "services/fonctions.dart",
      "log.dart"
    ],
    [
      "services/garmin_calendar_service.dart",
      "log.dart"
    ],
    [
      "services/meal_database_service.dart",
      "models/meal.dart"
    ],
    [
      "services/meal_database_service.dart",
      "log.dart"
    ],
    [
      "services/strava_service.dart",
      "log.dart"
    ],
    [
      "training_planner/training_planner_notifier.dart",
      "repositories/training_repository.dart"
    ],
    [
      "training_planner/training_planner_notifier.dart",
      "services/garmin_calendar_service.dart"
    ],
    [
      "training_planner/training_planner_notifier.dart",
      "training_planner/training_planner_state.dart"
    ],
    [
      "views/home/home_view.dart",
      "views/home/home_view_model.dart"
    ],
    [
      "views/home/home_view_model.dart",
      "core/base/base_view_model.dart"
    ],
    [
      "widget/added_food_tile.dart",
      "models/meal.dart"
    ],
    [
      "widget/added_food_tile.dart",
      "services/fonctions.dart"
    ],
    [
      "widget/decomposition_review_sheet.dart",
      "models/proposed_ingredient.dart"
    ],
    [
      "widget/decomposition_review_sheet.dart",
      "meal_input/meal_input_notifier.dart"
    ],
    [
      "widget/fat_breakdown_card.dart",
      "dashboard/dashboard_notifier.dart"
    ],
    [
      "widget/suggestion_meal_card.dart",
      "models/meal.dart"
    ],
    [
      "widget/suggestion_meal_card.dart",
      "services/fonctions.dart"
    ]
  ]
}
```