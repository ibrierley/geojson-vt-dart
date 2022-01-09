import 'dart:math' as math;
import 'package:test/test.dart';
import 'package:collection/collection.dart';
import '../lib/clip.dart';
import '../lib/classes.dart';
import '../lib/index.dart';


void main() {
  final leftPoint = {
    'type': 'Feature',
    'properties': {},
    'geometry': {
      'coordinates': [-540, 0],
      'type': 'Point'
    }
  };

  final rightPoint = {
    'type': 'Feature',
    'properties': {},
    'geometry': {
      'coordinates': [540, 0],
      'type': 'Point'
    }
  };

  test('handle point only in the rightside world', () {
    final vt = GeoJSONVT(rightPoint, {});
    expect(vt.tiles[0].features[0]['geometry'][0], 1);
    expect(vt.tiles[0].features[0]['geometry'][1], .5);
  });

  test('handle point only in the leftside world', () {
    final  vt = GeoJSONVT(leftPoint, {});
      expect(vt.tiles[0].features[0]['geometry'][0], 0);
      expect(vt.tiles[0].features[0]['geometry'][1], .5);
  });

  test('handle points in the leftside world and the rightside world', ()  {
    final vt = GeoJSONVT({
        'type': 'FeatureCollection',
        'features': [leftPoint, rightPoint]
    }, {});

    expect(vt.tiles[0].features[0]['geometry'][0], 0);
    expect(vt.tiles[0].features[0]['geometry'][1], .5);

    expect(vt.tiles[0].features[1]['geometry'][0], 1);
    expect(vt.tiles[0].features[1]['geometry'][1], .5);
  });

}
