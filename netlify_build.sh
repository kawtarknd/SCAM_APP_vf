#!/bin/bash

echo "🚀 Installing Flutter..."

git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:$(pwd)/flutter/bin"

flutter --version

echo "📦 Running flutter pub get..."
flutter pub get

echo "🏗️ Building Flutter Web..."
flutter build web --release

echo "🎉 Build complete!"
