import 'dart:math' as math;
import 'package:test/test.dart';
import 'package:collection/collection.dart';
import '../lib/clip.dart';
import '../lib/classes.dart';


void main() {

  final geom1 = [0,0,0,50,0,0,50,10,0,20,10,0,20,20,0,30,20,0,30,30,0,50,30,0,50,40,0,25,40,0,25,50,0,0,50,0,0,60,0,25,60,0];
  final geom2 = [0,0,0,50,0,0,50,10,0,0,10,0];

  test('Clip', () {
    var string = 'foo,bar,baz';
    expect(string.split(','), equals(['foo', 'bar', 'baz']));
  });

  test('Clip polylines', () {
    final clipped = clip([
      {'geometry': geom1, 'type': 'LineString', 'tags': 1, 'minX': 0, 'minY': 0, 'maxX': 50, 'maxY': 60},
      {'geometry': geom2, 'type': 'LineString', 'tags': 2, 'minX': 0, 'minY': 0, 'maxX': 50, 'maxY': 10}
    ], 1, 10, 40, 0, -double.infinity, double.infinity, {});

    final expected = [
      {'id': null, 'type': 'MultiLineString', 'geometry': [
        [10.0,0.0,1,40.0,0.0,1],
        [40.0,10.0,1,20.0,10.0,0,20.0,20.0,0,30.0,20.0,0,30.0,30.0,0,40.0,30.0,1],
        [40.0,40.0,1,25.0,40.0,0,25.0,50.0,0,10.0,50.0,1],
        [10.0,60.0,1,25.0,60.0,0]], 'tags': 1, 'minX': 10, 'minY': 0, 'maxX': 40, 'maxY': 60},
      {'id': null, 'type': 'MultiLineString', 'geometry': [
        [10.0,0.0,1,40.0,0.0,1],
        [40.0,10.0,1,10.0,10.0,1]], 'tags': 2, 'minX': 10, 'minY': 0, 'maxX': 40, 'maxY': 10}
    ];

    expect(DeepCollectionEquality().equals(clipped, expected), true);
  });

  final List geom = geom1.sublist(0);
  geom.size = 0;
  for (int i = 0; i < geom.length - 3; i += 3) {
    final dx = geom[i + 3] - geom[i];
    final dy = geom[i + 4] - geom[i + 1];
    geom.size += math.sqrt(dx * dx + dy * dy);
  }
  geom.start = 0;
  geom.end = geom.size;

  print("GEOM $geom");

  List clipped = clip([{'geometry': geom, 'type': 'LineString', 'minX': 0, 'minY': 0, 'maxX': 50, 'maxY': 60}],
      1, 10, 40, 0, -double.infinity, double.infinity, {'lineMetrics': true});

  List test1 = [];
  for (var g in clipped) {
    List gl = g['geometry'];
    test1.add([gl.start, gl.end]);
  }

  test('clips lines with line metrics on', () {
    expect(test1,  [[10, 40], [70, 130], [160, 200], [230, 245]]);
  });

  test('clips polygons', () {
    final List clipped = clip([
      {'geometry': closed(geom1), 'type': 'Polygon', 'tags': 1, 'minX': 0, 'minY': 0, 'maxX': 50, 'maxY': 60},
      {'geometry': closed(geom2), 'type': 'Polygon', 'tags': 2, 'minX': 0, 'minY': 0, 'maxX': 50, 'maxY': 10}
    ], 1, 10, 40, 0, -double.infinity, double.infinity, {});

    final expected = [
      {'id': null, 'type': 'Polygon', 'geometry': [[10,0,1,40,0,1,40,10,1,20,10,0,20,20,0,30,20,0,30,30,0,40,30,1,40,40,1,25,40,0,25,50,0,10,50,1,10,60,1,25,60,0,10,24,1,10,0,1]], 'tags': 1, 'minX': 10, 'minY': 0, 'maxX': 40, 'maxY': 60},
      {'id': null, 'type': 'Polygon', 'geometry': [[10,0,1,40,0,1,40,10,1,10,10,1,10,0,1]], 'tags': 2,  'minX': 10, 'minY': 0, 'maxX': 40, 'maxY': 10}
    ];

    expect(clipped, expected);

  });

  test('clip points', () {
    final  clipped = clip([
      {'geometry': geom1, 'type': 'MultiPoint', 'tags': 1, 'minX': 0, 'minY': 0, 'maxX': 50, 'maxY': 60},
      {'geometry': geom2, 'type': 'MultiPoint', 'tags': 2, 'minX': 0, 'minY': 0, 'maxX': 50, 'maxY': 10}
    ], 1, 10, 40, 0, -double.infinity, double.infinity, {});


    expect(clipped, [{'id': null, 'type': 'MultiPoint',
      'geometry': [20,10,0,20,20,0,30,20,0,30,30,0,25,40,0,25,50,0,25,60,0], 'tags': 1, 'minX': 20, 'minY': 10, 'maxX': 30, 'maxY': 60}]);
  });



}

List closed(List geometry) {
  var l = [[...geometry, ...geometry.sublist(0, 3)]];
  print("L $l");
  return l;
}
