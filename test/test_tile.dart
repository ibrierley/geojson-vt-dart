import 'dart:io';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:test/test.dart';
import '../lib/clip.dart';
import '../lib/classes.dart';
import '../lib/index.dart';


void main() async {

  final List square = [{
    "geometry": [[[-64, 4160], [-64, -64], [4160, -64], [4160, 4160], [-64, 4160]]],
    "type": 3,
    "tags": {"name": 'Pennsylvania', "density": 284.3},
    "id": '42'
  }];

  /* // works
  test('getTile: unbuffered tile left/right edges', () {
    final index = GeoJSONVT({
      'type': 'LineString',
      'coordinates': [[0, 90], [0, -90]]
    }, {
      'buffer': 0
    });
    var x = index.getTile(2, 1, 1);
    expect(x, null);
    x = index.getTile(2, 2, 1);
    expect(x!.features, [{'geometry': [[[0, 0], [0, 4096]]], 'type': 2, 'tags': null}]);

  });

   */
/*
  test('getTile: unbuffered tile top/bottom edges', () {
    final index = GeoJSONVT({
    'type': 'LineString',
    'coordinates': [[-90, 66.51326044311188], [90, 66.51326044311188]]
    }, {
      'buffer': 0
    });

    expect(index.getTile(2, 1, 0)!.features, [{'geometry': [[[0, 4096], [4096, 4096]]], 'type': 2, 'tags': null}]);
    expect(index.getTile(2, 1, 1)!.features, []);

  });

 */

  /* works
  test('getTile: polygon clipping on the boundary', () {
    final index = GeoJSONVT({
      'type': 'Polygon',
      'coordinates': [[
        [42.1875, 57.32652122521708],
        [47.8125, 57.32652122521708],
        [47.8125, 54.16243396806781],
        [42.1875, 54.16243396806781],
        [42.1875, 57.32652122521708]
      ]]
    }, {
      'buffer': 1024
    });

      expect(index.getTile(5, 19, 9)!.features, [{
        'geometry': [[[3072, 3072], [5120, 3072], [5120, 5120], [3072, 5120], [3072, 3072]]],
        'type': 3,
        'tags': null
      }]);

  });

   */

  var us_states_z7_37_48 = await File('data/us-states-z7-37-48.json').readAsString();



  File('us-states.json').readAsString().then((String contents) {
    var index = GeoJSONVT(json.decode(contents), {'debug': 2});
    var t = index.getTile(9, 148, 192);

    /* works
    test('us2', (){
      expect(index.getTile(7, 37, 48)!.features, jsonDecode(us_states_z7_37_48));
    });
     */
    /* works
    test('us3', (){
      expect(index.getTile(11, 800, 400)?.features, null);
    });

     */
    /*
    test('us4', (){
      expect(index.getTile(-5, 123.25, 400.25)?.features, null);
    });


     */
    /* works
    test('us5', (){
      expect(index.getTile(25,200,200)?.features, null);
    });

     */
    /* works
    test('Tile', () {
      expect(t!.features, square);
    });
     */
  });







    //expect(DeepCollectionEquality().equals(clipped, expected), true);



}
