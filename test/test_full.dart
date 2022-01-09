import 'package:test/test.dart';
import 'dart:math' as math;
import 'dart:io';
import 'dart:convert';
import '../lib/index.dart';
import '../lib/simplify.dart';
import '../lib/classes.dart';

void main() async {

  /*
  var data1 = jsonDecode(await File('data/single-geom.json').readAsString());
  var data2 = jsonDecode(await File('data/single-geom-tiles.json').readAsString());
  test('single geom', () {
    expect(genTiles(data1, {'indexMaxZoom': 0, 'indexMaxPoints': 10000}), data2  );
  });
  */


  var data3 = jsonDecode(await File('data/us-states.json').readAsString());
  var data4 = jsonDecode(await File('data/us-states-tiles.json').readAsString());
  var partialus = jsonDecode(await File('data/us-states-partial.json').readAsString());
  var index = GeoJSONVT(data3, {'indexMaxZoom': 7, 'indexMaxPoints': 200});



  ///List t1 = index.getTile(0,0,0)!.features;
  ///print("${t1.length}");

  test('US States', () {
    expect(genTiles(data3, {'indexMaxZoom': 7, 'indexMaxPoints': 200} ), data4  );
  });

  //exit(2);

  //test('us states', () {
  //    expect(t1, partialus  );
  //}, skip: false);

  /*
  for(var c=0; c<t1.length; c++) {
    print("${t1[c].length} ${partialus[c].length} ");
    print("LEN!!!!!!!!!!!!!!!!!!! ${t1[c]['geometry'].length} ${partialus[c]['geometry'].length} ");
    test('', () {
      for (var x = 0; x < t1[x]['geometry'].length; x++) {
        print("${t1[c]['geometry'][x]} ??????? ${partialus[c]['geometry'][x] }");
        for( var y = 0; y < t1[c]['geometry'][x].length; y++) {
          print("${t1[c]['geometry'][x][y]} XXXXXX ${partialus[c]['geometry'][x][y] }");
        }
        //expect(t1[c]['geometry'][x], partialus[c]['geometry'][x]);
      }
    });
    //test('x', (){
      //expect(t1[c], partialus[c]);
    //});

  }



   */

  //print("${index.getTile(0,0,0)?.features}");

  //var t = genTiles(data3, {'indexMaxZoom': 7, 'indexMaxPoints': 200});
  //print("${t["z0-0-0"]}");
  ///test('us states', () {
  ///  expect(genTiles(data3, {'indexMaxZoom': 7, 'indexMaxPoints': 200}), data4  );
  ///});


  //var t = genTiles(data3, {'indexMaxZoom': 7, 'indexMaxPoints': 200});
  //print("$t");

/* Works
  var data5 = jsonDecode(await File('data/dateline.json').readAsString());
  var data6 = jsonDecode(await File('data/dateline-tiles.json').readAsString());
  test('Dateline', () {
    expect(genTiles(data5, {'indexMaxZoom': 0, 'indexMaxPoints': 10000}), data6  );
  });
 */
/* Passes
  var data7 = jsonDecode(await File('data/dateline.json').readAsString());
  var data8 = jsonDecode(await File('data/dateline-metrics-tiles.json').readAsString());
  test('Dateline linemetrics', () {
    expect(genTiles(data7, {'indexMaxZoom': 0, 'indexMaxPoints': 10000, 'lineMetrics': true} ), data8  );
  });


 */

  /* Passes!
  var data9 = jsonDecode(await File('data/feature.json').readAsString());
  var data10 = jsonDecode(await File('data/feature-tiles.json').readAsString());
  test('feature', () {
    expect(genTiles(data9, {'indexMaxZoom': 0, 'indexMaxPoints': 10000} ), data10  );
  });
   */

  /* Passes!
  var data11 = jsonDecode(await File('data/collection.json').readAsString());
  var data12 = jsonDecode(await File('data/collection-tiles.json').readAsString());
  test('Collection', () {
    expect(genTiles(data11, {'indexMaxZoom': 0, 'indexMaxPoints': 10000} ), data12  );
  });
   */
  /* Passes!
  var data13 = jsonDecode(await File('data/single-geom.json').readAsString());
  var data14 = jsonDecode(await File('data/single-geom-tiles.json').readAsString());
  test('Single Geom', () {
    expect(genTiles(data13, {'indexMaxZoom': 0, 'indexMaxPoints': 10000} ), data14  );
  });
   */

/* passes
  var data15 = jsonDecode(await File('data/ids.json').readAsString());
  var data16 = jsonDecode(await File('data/ids-promote-id-tiles.json').readAsString());
  test('ids promote', () {
    expect(genTiles(data15, {'indexMaxZoom': 0, 'promoteId': 'prop0'} ), data16  );
  });

 */
  /* /passes
  var data17 = jsonDecode(await File('data/ids.json').readAsString());
  var data18 = jsonDecode(await File('data/ids-generate-id-tiles.json').readAsString());
  test('Generate id', () {
    expect(genTiles(data17, {'indexMaxZoom': 0, 'generateId': true} ), data18  );
  });


   */
}

Map genTiles(data, options) {
  final index = GeoJSONVT(data, extend({
    'indexMaxZoom': 0,
    'indexMaxPoints': 10000
  }, options));

  final output = {};
  //print("${index.tiles}");

  var tiles = index.tiles;
  tiles.forEach((id, idx) {
      final tile = tiles[id];
      final z = tile.z;
      var i = "z$z-${tile.x}-${tile.y}";
      //print("\n$i ${index.runtimeType}");
      output[i] = index.getTile(z, tile.x, tile.y)!.features;
  });

  return output;
}

Map extend(Map dest, Map src) {
  //print("EXTENDING!!!");
  src.forEach((key, value) {
    dest[key] = src[key];
  });
  // print("EXT $dest");
  return dest;
}
