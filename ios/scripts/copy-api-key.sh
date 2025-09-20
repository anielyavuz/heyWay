#!/bin/bash

# Script to copy API key from Dart file to iOS configuration

# Read the API key from the Dart file
API_KEY=$(grep -o "googlePlacesApiKey = '[^']*'" "${SRCROOT}/../lib/config/api_keys.dart" | sed "s/googlePlacesApiKey = '//g" | sed "s/'//g")

# Replace the placeholder in Info.plist
/usr/libexec/PlistBuddy -c "Set :GMSApiKey $API_KEY" "${SRCROOT}/Runner/Info.plist"

echo "Google Maps API key injected into Info.plist"