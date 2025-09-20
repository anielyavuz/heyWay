import 'package:flutter/material.dart';

class MapStyles {
  MapStyles._();

  static const String lightStyleUrl =
      'https://demotiles.maplibre.org/style.json';

  static const String darkStyleUrl =
      'https://tiles.stadiamaps.com/styles/alidade_smooth_dark.json';

  static String styleForBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? darkStyleUrl : lightStyleUrl;
  }
}
