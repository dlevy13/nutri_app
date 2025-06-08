#!/bin/bash

echo "🔁 Nettoyage du dossier web/..."
rm -rf web

echo "📦 Recréation du projet web Flutter..."
flutter create .

echo "🧼 Nettoyage du build..."
flutter clean

echo "📥 Récupération des dépendances..."
flutter pub get

echo "🏗 Build Flutter Web..."
flutter build web

echo "🌐 Lancement du serveur local sur http://localhost:8080"
cd build/web
python3 -m http.server 8080
