import 'dart:math' as math;
//import 'package:geojson_vi/geojson_vi.dart';
import 'classes.dart';

Map createFeature(id, type, List geometry, tags) {

  Map<String, dynamic> feature = {
    'geometry': geometry,
    'id': id == null ? null : id,
    'type': type,
    'tags': tags,
    'minX': double.infinity,
    'minY': double.infinity,
    'maxX': -double.infinity,
    'maxY': -double.infinity
  };

  var l = feature['geometry'] as List;


  if (type == 'Point' || type == 'MultiPoint' || type == 'LineString') {
    calcLineBBox(feature, geometry);

  } else if (type == 'Polygon') {
    // the outer ring (ie [0]) contains all inner rings
    calcLineBBox(feature, geometry[0]);

  } else if (type == 'MultiLineString') {
    for (final line in geometry) {
      calcLineBBox(feature, line);
    }

  } else if (type == 'MultiPolygon') {
    for (final polygon in geometry) {
      // the outer ring (ie [0]) contains all inner rings
      calcLineBBox(feature, polygon[0]);
    }
  }

  return feature;
}

void calcLineBBox(Map feature, List geom) {
  for (var i = 0; i < geom.length; i += 3) {

    if(feature['minX'] > geom[i]) feature['minX'] = geom[i];
    if(feature['minY'] > geom[i + 1]) feature['minY'] = geom[i + 1];
    if(feature['maxX'] < geom[i]) feature['maxX'] = geom[i];
    if(feature['maxY'] < geom[i + 1]) feature['maxY'] = geom[i + 1];

  }
}
