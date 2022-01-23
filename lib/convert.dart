import 'dart:math' as math;
import 'feature.dart';
import 'package:geojson_vi/geojson_vi.dart';
import 'clip.dart';
import 'simplify.dart';
import 'classes.dart';
import 'dart:io';

List convert( Map data, options ) {
  List features = [];

  if(data['type'] == 'FeatureCollection') {
    for (int i = 0; i < data['features'].length; i++) {
      convertFeature(features, data['features'][i], options, i);
    }
  } else if (data['type'] == 'Feature') {
    convertFeature(features, data, options, null);

  } else {

    // single geometry or a geometry collection
    convertFeature(features, {'geometry': data}, options, null);
  }

  return features;
}

void convertFeature( List featureCollection, geojson, options, index ) {

  if (geojson['geometry'] == null || geojson['geometry'].isEmpty) return;
  var type = geojson['geometry']['type'];

  var coords = geojson['geometry']['coordinates'];

  var tolerance = math.pow(options['tolerance'] / ((1 << options['maxZoom']) * options['extent']), 2);

  List geometry = [];
  var id = geojson['id'];

  if (options['promoteId'] != null) {
    id = geojson['properties'][options['promoteId']];
  } else if (options['generateId']) {
    id = index == null ? 0 : index;
  }

  if (type == 'Point') {
    convertPoint(coords, geometry);

  } else if (type ==  'MultiPoint') {
    for (var p in coords) {
      convertPoint(p, geometry);
    }

  } else if (type == 'LineString') {
    convertLine(coords, geometry, tolerance, false);

  } else if (type == 'MultiLineString') {
    if (options['lineMetrics'] != null && options['lineMetrics']) {
      // explode into linestrings to be able to track metrics
      for (var line in coords) {
        geometry = [];
        convertLine(line, geometry, tolerance, false);

        featureCollection.add(createFeature(id, 'LineString', geometry, geojson['properties']));
      }
      return;
    } else {
      convertLines(coords, geometry, tolerance, false);
    }

  } else if (type ==  'Polygon') {
    convertLines(coords, geometry, tolerance, true);

  } else if (type ==  'MultiPolygon') {
    for (var polygon in coords) {
      var newPolygon = [];
      convertLines(polygon, newPolygon, tolerance, true);
      geometry.add(newPolygon);
    }

  } else if (type ==  'GeometryCollection') {
    for (final singleGeometry in geojson['geometry']['geometries']) {
      convertFeature(featureCollection, {
        'id': id, // to do
        'geometry': singleGeometry,
        'properties': geojson['properties']
      }, options, index);

    }
    return;
  } else {
    print('Input data is not a valid GeoJSON object.');
  }

  featureCollection.add(createFeature(id, type, geometry, geojson['properties']));

  return;
}

void convertPoint(coords, out) {
  out.addAll([projectX(coords[0]), projectY(coords[1]), 0]);
}

double projectX(x) {
  return x / 360 + 0.5;
}

double projectY(y) {
  double sin = math.sin(y * math.pi / 180);
  double y2 = 0.5 - 0.25 * math.log((1 + sin) / (1 - sin)) / math.pi;
  return (y2 < 0) ? 0 : (y2 > 1 ? 1 : y2);
}

void convertLines(rings, out, tolerance, isPolygon) {
  for (var i = 0; i < rings.length; i++) {
    List geom = [];
    convertLine(rings[i], geom, tolerance, isPolygon);
    out.add(geom);
  }
}

void convertLine(ring, List out, tolerance, bool isPolygon) {
  var x0, y0;
  var size = 0.0;

  for (var j = 0; j < ring.length; j++) {
    var x = projectX(ring[j][0]);
    var y = projectY(ring[j][1]);

    out.addAll([x, y, 0.999]); // maybe wrong...

    if (j > 0) {
      if (isPolygon) {
        size += (x0 * y - x * y0) / 2; // area
      } else {
        size += math.sqrt(math.pow(x - x0, 2.0) + math.pow(y - y0, 2.0)); // length
      }
    }
    x0 = x;
    y0 = y;
  }

  final last = out.length - 3;
  out[2] = 1;

  simplify(out, 0, last, tolerance);

  out[last + 2] = 1;
  out.size = size.abs();
  out.start = 0;
  out.end = out.size;

}
