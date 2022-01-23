import 'dart:math' as math;
import 'classes.dart';

class SimpTile {
  List features = [];
  int numPoints = 0;
  int numSimplified = 0;
  int numFeatures = -1; // = features.length;
  var source = null;
  num x = 0;
  num y = 0;
  num z;
  bool transformed = false;
  num minX = 2;
  num minY = 1;
  num maxX = -1;
  num maxY = 0;

  SimpTile(this.features, this.z, tx, ty) { x = tx; y = ty; }

  @override String toString() {
    return "SimpTile:    numPoints: $numPoints numSimplified: $numSimplified numFeatures: $numFeatures source: $source xyz $x,$y,$z transformed: $transformed minX: $minX minY $minY maxX: $maxX maxY: $maxY features: $features";
  }

}

SimpTile createTile(List features, z, tx, ty, Map options) {
  num tolerance = (z == options['maxZoom']) ? 0 : options['tolerance'] / ((1 << z) * options['extent']);

  SimpTile tile = SimpTile([], z, tx, ty);
  tile.numFeatures = features.length;

  int len = features.length;

  for(var feature in features)
    addFeature(tile, feature, tolerance, options);

  return tile;
}

addFeature(SimpTile tile, feature, tolerance, options) {
  final geom = feature['geometry'] as List;
  final type = feature['type'];
  final simplified = [];

  tile.minX = math.min(tile.minX, feature['minX']);
  tile.minY = math.min(tile.minY, feature['minY']);
  tile.maxX = math.max(tile.maxX, feature['maxX']);
  tile.maxY = math.max(tile.maxY, feature['maxY']);

  if (type == "Point" || type == "MultiPoint") {
    for (int i = 0; i < geom.length; i += 3) {
      simplified.addAll([geom[i], geom[i + 1]]);
      tile.numPoints++;
      tile.numSimplified++;
    }
  }  else if (type == "LineString") {
    addLine(simplified, geom, tile, tolerance, false, false);
  } else if (type == "MultiLineString" || type == "Polygon") {
    for (int i = 0; i < geom.length; i++) {
      addLine(simplified, geom[i], tile, tolerance, type == "Polygon", i == 0);
    }

  } else if (type == "MultiPolygon") {

    for (int k = 0; k < geom.length; k++) {
      final polygon = geom[k];
      for (int i = 0; i < polygon.length; i++) {
        addLine(simplified, polygon[i], tile, tolerance, true, i == 0);
      }
    }
  }

  if (simplified.length > 0) {
    var tags;
    if( feature['tags'] != null ) tags = feature['tags'];

    if (type == "LineString" && options['lineMetrics']) {
      tags = {};
      feature['tags'].forEach((key, val) {
        tags[key] = feature['tags'][key];
      });
      tags['mapbox_clip_start'] = geom.start / geom.size;
      tags['mapbox_clip_end'] = geom.end / geom.size;
    }

    final tileFeature = {
      'geometry' : simplified,
      'type' : (type == "Polygon" || type == "MultiPolygon") ? 3 :
        (type == "LineString" || type == "MultiLineString") ? 2 : 1,
      'tags' : tags
    };

    if (feature['id'] != null) {
      tileFeature['id'] = feature['id'];
    }
    tile.features.add(tileFeature);
  }
}

void addLine(result, List geom, tile, tolerance, isPolygon, isOuter) {
  final sqTolerance = tolerance * tolerance;

  List g = geom as List;

  if (tolerance > 0 && (g.size < (isPolygon ? sqTolerance : tolerance))) {
    tile.numPoints += (g.length / 3).toInt();
    return;
  }

  final ring = [];

  for (int i = 0; i < geom.length; i += 3) {
    if (tolerance == 0 || geom[i + 2] > sqTolerance) {
      tile.numSimplified++;
      ring.addAll([geom[i], geom[i + 1]]);
    }
    tile.numPoints++;
  }

  if (isPolygon) rewind(ring, isOuter);

  result.add(ring);
}

void rewind(ring, clockwise) {
  double area = 0;
  for (int i = 0, len = ring.length, j = len - 2; i < len; j = i, i += 2) {
    area += ((ring[i] - ring[j]) * (ring[i + 1] + ring[j + 1])).toDouble();
  }

  if (area > 0 == clockwise) {
    for (int i = 0, len = ring.length; i < len / 2; i += 2) {
      final x = ring[i];
      final y = ring[i + 1];
      ring[i] = ring[len - 2 - i];
      ring[i + 1] = ring[len - 1 - i];
      ring[len - 2 - i] = x;
      ring[len - 1 - i] = y;
    }
  }
}
