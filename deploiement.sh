#!/bin/bash

set -euo pipefail

echo "Build web en cours..."
flutter clean
flutter pub get
flutter build web \
  --pwa-strategy=none \
  --dart-define=SUPABASE_URL=https://jasofcbxjgnuydohlyzk.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imphc29mY2J4amdudXlkb2hseXprIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY4MzMzNTAsImV4cCI6MjA4MjQwOTM1MH0.2_EJl6zbR-aY2ofpPIWqEylZYFcKDWX8lmGjpePzj9A

echo "Copie des routes statiques..."
/bin/mkdir -p build/web/reset-password
/bin/cp -R web-extra/reset-password/. build/web/reset-password/

echo "Déploiement Firebase Hosting..."
firebase deploy --only hosting

echo "Déploiement terminé."
echo "Sur iPhone web app, supprimer puis réajouter l'icône si une ancienne version persiste."
