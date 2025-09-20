import 'dart:convert';
import 'package:flutter/material.dart';

class MapStyles {
  MapStyles._();

  // CartoDB tiles (keep for dark mode)
  static const String _cartoDbDarkTileUrl = 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png';
  
  // Stamen Toner (black and white with good road visibility)
  static const String _stamenTonerUrl = 'https://stamen-tiles.a.ssl.fastly.net/toner/{z}/{x}/{y}.png';
  
  // OpenStreetMap Humanitarian (better road visibility)
  static const String _osmHumanitarianUrl = 'https://tile-{s}.openstreetmap.fr/hot/{z}/{x}/{y}.png';
  
  // Stamen Terrain (shows roads clearly)
  static const String _stamenTerrainUrl = 'https://stamen-tiles.a.ssl.fastly.net/terrain/{z}/{x}/{y}.png';
  
  // OpenStreetMap France (reliable alternative)
  static const String _osmFranceUrl = 'https://tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png';

  static String get lightStyle {
    return jsonEncode({
      "version": 8,
      "name": "Clear Roads Light",
      "sources": {
        "osm": {
          "type": "raster",
          "tiles": [_osmFranceUrl],
          "tileSize": 256,
          "attribution": "&copy; <a href='https://www.openstreetmap.org/copyright'>OpenStreetMap</a> contributors, Tiles courtesy of OpenStreetMap France",
          "maxzoom": 19
        }
      },
      "layers": [
        {
          "id": "osm",
          "type": "raster",
          "source": "osm",
          "minzoom": 0,
          "maxzoom": 19
        }
      ]
    });
  }

  static String get darkStyle {
    return jsonEncode({
      "version": 8,
      "name": "OpenStreetMap Dark",
      "sources": {
        "osm": {
          "type": "raster",
          "tiles": [_cartoDbDarkTileUrl],
          "tileSize": 256,
          "attribution": "&copy; <a href='https://www.openstreetmap.org/copyright'>OpenStreetMap</a> contributors &copy; <a href='https://carto.com/attributions'>CARTO</a>",
          "maxzoom": 18
        }
      },
      "layers": [
        {
          "id": "osm",
          "type": "raster",
          "source": "osm",
          "minzoom": 0,
          "maxzoom": 18
        }
      ]
    });
  }

  static String get standardOsmStyle {
    return jsonEncode({
      "version": 8,
      "name": "OpenStreetMap Humanitarian",
      "sources": {
        "osm-hot": {
          "type": "raster",
          "tiles": [_osmHumanitarianUrl],
          "tileSize": 256,
          "attribution": "&copy; <a href='https://www.openstreetmap.org/copyright'>OpenStreetMap</a> contributors, Tiles courtesy of <a href='https://hot.openstreetmap.org/' target='_blank'>Humanitarian OpenStreetMap Team</a>",
          "maxzoom": 19
        }
      },
      "layers": [
        {
          "id": "osm-hot",
          "type": "raster",
          "source": "osm-hot",
          "minzoom": 0,
          "maxzoom": 19
        }
      ]
    });
  }

  static String get detailedRoadsStyle {
    return jsonEncode({
      "version": 8,
      "name": "Terrain with Roads",
      "sources": {
        "terrain": {
          "type": "raster",
          "tiles": [_stamenTerrainUrl],
          "tileSize": 256,
          "attribution": "Map tiles by <a href='http://stamen.com'>Stamen Design</a>, <a href='http://creativecommons.org/licenses/by/3.0'>CC BY 3.0</a> &mdash; Map data &copy; <a href='https://www.openstreetmap.org/copyright'>OpenStreetMap</a> contributors",
          "maxzoom": 18
        }
      },
      "layers": [
        {
          "id": "terrain-layer",
          "type": "raster",
          "source": "terrain",
          "minzoom": 0,
          "maxzoom": 18
        }
      ]
    });
  }

  // Yeni ultra net yol stili
  static String get ultraRoadsStyle {
    return jsonEncode({
      "version": 8,
      "name": "Ultra Clear Roads",
      "sources": {
        "toner": {
          "type": "raster",
          "tiles": [_stamenTonerUrl],
          "tileSize": 256,
          "attribution": "Map tiles by <a href='http://stamen.com'>Stamen Design</a>, <a href='http://creativecommons.org/licenses/by/3.0'>CC BY 3.0</a> &mdash; Map data &copy; <a href='https://www.openstreetmap.org/copyright'>OpenStreetMap</a> contributors",
          "maxzoom": 18
        }
      },
      "layers": [
        {
          "id": "toner-layer",
          "type": "raster",
          "source": "toner",
          "minzoom": 0,
          "maxzoom": 18
        }
      ]
    });
  }

  static String styleForBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? darkStyle : lightStyle;
  }
}
