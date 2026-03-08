#!/bin/bash

echo "🚀 Lancement de l'app Flutter (Chrome)..."
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://jasofcbxjgnuydohlyzk.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imphc29mY2J4amdudXlkb2hseXprIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY4MzMzNTAsImV4cCI6MjA4MjQwOTM1MH0.2_EJl6zbR-aY2ofpPIWqEylZYFcKDWX8lmGjpePzj9A
