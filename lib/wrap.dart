import 'feature.dart';
import 'clip.dart';
//import 'package:geojson_vi/geojson_vi.dart';
import 'classes.dart';

List wrap(features, options) {
  final buffer = options['buffer'] / options['extent'];
  List merged = features;
  final List left  = clip(features, 1, -1 - buffer, buffer,     0, -1, 2, options); // left world copy
  final List right = clip(features, 1,  1 - buffer, 2 + buffer, 0, -1, 2, options); // right world copy

  if (left.isNotEmpty || right.isNotEmpty) {
    merged = clip(features, 1, -buffer, 1 + buffer, 0, -1, 2, options); // center world copy

    if (left.isNotEmpty) merged = shiftFeatureCoords(left, 1) + merged; // merge left into center
    if (right.isNotEmpty) merged = merged + shiftFeatureCoords(right, -1); // merge right into center
  }

  return merged;
}

List shiftFeatureCoords(features, offset) {
  final newFeatures = [];

  for (int i = 0; i < features.length; i++) {
    final feature = features[i];
    final type = feature['type'];

    var newGeometry;

    if (type == "Point" || type == "MultiPoint" || type == "LineString") {
      newGeometry = shiftCoords(feature['geometry'], offset);

    } else if (type == "MultiLineString" || type == "Polygon") {
      newGeometry = [];
      for (var line in feature['geometry']) {
        newGeometry.add(shiftCoords(line, offset));
      }
    } else if (type == "MultiPolygon") {
      newGeometry = [];
      for (var polygon in feature['geometry']) {
        final newPolygon = [];
        for (var line in polygon) {
          newPolygon.add(shiftCoords(line, offset));
        }
        newGeometry.add(newPolygon);
      }
    }
    //if(newGeometry != null) {
      newFeatures.add(
          createFeature(feature['id'], type, newGeometry, feature['tags']));
    //} else {
    //  print("newGeometry was null, not adding");
   // }
  }

  return newFeatures;
}

List shiftCoords(List points, offset) {
  List<num> newPoints = [];
  newPoints.size = points.size;

  if (points.start != null) {
    newPoints.start = points.start;
    newPoints.end = points.end;
  }

  for (int i = 0; i < points.length; i += 3) {
    newPoints.addAll([points[i] + offset, points[i + 1], points[i + 2]]);
  }
  return newPoints;
}
