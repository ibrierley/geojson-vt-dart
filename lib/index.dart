library geojson_vt_dart;

import 'convert.dart';
//import 'wrap.dart';
//import 'clip.dart';
import 'tile.dart';
import 'clip.dart';
import 'dart:convert';
import 'transform.dart';
import 'wrap.dart';
import 'package:geojson_vi/geojson_vi.dart';
import 'classes.dart';
import 'dart:io';
/*

extension JSList<T> on List<T> {
  static final _startValues = Expando<int>();

  int get start => _startValues[this] ?? 0;
  set start(int x) => _startValues[this] = x;
}

 */

Map defaultOptions = {
  'maxZoom': 14,            // max zoom to preserve detail on
  'indexMaxZoom': 5,        // max zoom in the tile index
  'indexMaxPoints': 100000, // max number of points per tile in the tile index
  'tolerance': 3,           // simplification tolerance (higher means simpler)
  'extent': 4096,           // tile extent
  'buffer': 64,             // tile buffer on each side
  'lineMetrics': false,     // whether to calculate line metrics
  'promoteId': null,        // name of a feature property to be promoted to feature.id
  'generateId': false,      // whether to generate feature ids. Cannot be used with promoteId
  'debug': 2                // logging level (0, 1 or 2)
};

class GeoJSONVT {
  Map options;
  Map tiles = {};
  List tileCoords = [];
  Map stats = {};
  int total = 0;

  GeoJSONVT( data, passedOptions) : options = extend({'ss': 'ff'}, passedOptions) {///extend(defaultOptions, passedOptions) {
    options = extend(defaultOptions, options);

    //print("DEFOPTIONS!!!!!!!!!!!!!! $defaultOptions");
    //print("OPTIONS!!!!!!!!!!!!!! $passedOptions");


    print("Start GeoJSONVT $options");

    var debug = options['debug'];

    if (options['maxZoom'] < 0 || options['maxZoom'] > 24) throw Exception('maxZoom should be in the 0-24 range');
    if (options['promoteId'] != null && options['generateId']) throw Exception('promoteId and generateId cannot be used together.');

    // projects and adds simplification info
    //var features = 1; //convert(data, options);
    //print("Data is $data");
    var features = convert(data, options);
    print("OPTIONS $options");

    //print("FEATURES $features");

    List t = features[0]['geometry'];
    //print("features after convert are $features, size is ${t.size}");

    tiles = {};
    List tileCoords = [];

    if( debug > 0 ) {
      //stats = {};
      //total = 0;
    }

    //print("FEATURE LENIND1 IS ${features.length}");

    // wraps features (ie extreme west and extreme east)
    features = wrap(features, options);
    //print("features $features");



    if (features.length > 0) splitTile(features, 0, 0, 0, null, null, null);

    //print("$options");

   // print("$tiles");

    ///print("FEATURES OF 0,0,0 $features");
    ///print("TILES WITH 0,0,0 added are $tiles");

    //exit(2);

  }

  @override toString() {
    var out = "";
    tiles.forEach((tile,index) {
      out += "Index: $index, Tile:" + tile.toString();
    });
    return out;
  }

  // splits features from a parent tile to sub-tiles.
  // z, x, and y are the coordinates of the parent tile
  // cz, cx, and cy are the coordinates of the target tile
  //
  // If no target tile is specified, splitting stops when we reach the maximum
  // zoom or the number of points is low as specified in the options.
  splitTile(List features, z, x, y, cz, cx, cy) {
    final List stack = [features, z, x, y];
    final options = this.options;
    final debug = options['debug'];

    //print("FEATURE LENSPLITTILE IS ${features.length}");
    //print("XXSPLITTILE $z $x $y $cz $cx $cy    $features");

    // avoid recursion by using a processing queue

    //print("STACK IS ${stack.length}");
    while (stack.length > 0) {
      y = stack.removeLast();
      x = stack.removeLast();
      z = stack.removeLast();


      //print("HERE1 FEATURES LEN IS ${features.length} stack len is ${stack.length}");
      features = stack.removeLast();
      //print("HERE2 FEATURES LEN IS ${features.length} stack len is ${stack.length}");

      //print("Stack Length ${stack.length} features $features");

      final z2 = 1 << z;
      final id = toID(z, x, y);
      var tile = this.tiles[id];


      //print("Split tile: ID is $id from $z $x $y   tile for id $id is $tile");

      if (tile == null) {
        //print("tile is null");
        //if (debug > 1) console.time('creation');

        if(features.isNotEmpty ) {
          ///print("Creating tile from Index.dart $z $x $y $features ${features[0]!['geometry']}");
        } else {
          print("features is empty ");
        }
        tile = this.tiles[id] = createTile(features, z, x, y, options);

        if( options['debug'] > 1 ) {
          print("tile z$z-$x-$y (features: ${tile.numFeatures}, points: ${tile.numPoints}, simplified: ${tile.numSimplified})");
        }
        //print("SPLIT TILE $tile");

        //print("tile is $tile features are $features");;
        this.tileCoords.add({z, x, y});


        if (debug > 0) {
          if (debug > 1) {
            //print("tile $z-$x-$y (features: ${tile.numFeatures}, ${tile.numPoints}, ${tile.numSimplified})");
          }
          final key = "z${z}";
          this.stats[key] = (this.stats[key] ?? 0) + 1;
          this.total++;
        }
      }

      //print("TILE SOURCE INDEX IS ${tile.source}");
      // save reference to original geometry in tile so that we can drill down later if we stop now
      tile.source = features;

      //print("here2");

      // if it's the first-pass tiling
      if (cz == null) {
        // stop tiling if we reached max zoom, or if the tile is too simple
        if (z == options['indexMaxZoom'] || tile.numPoints <= options['indexMaxPoints']) continue;
        // if a drilldown to a specific tile
      } else if (z == options['maxZoom'] || z == cz) {
        // stop tiling if we reached base zoom or our target tile zoom
        continue;
      } else if (cz != null) {
        // stop tiling if it's not an ancestor of the target tile
        final zoomSteps = cz - z;
        if (x != cx >> zoomSteps || y != cy >> zoomSteps) continue;
      }

      // if we slice further down, no need to keep source geometry
      tile.source = null;

      if (features.length == 0) continue;

      if (debug > 1) print('clipping');

      //print("BUFFER!!!! ${options['buffer']} ${options['extent']}");

      // values we'll use for clipping
      final k1 = 0.5 * options['buffer'] / options['extent'];
      final k2 = 0.5 - k1;
      final k3 = 0.5 + k1;
      final k4 = 1 + k1;

     // print("KKKKKKK splittile $k1 $k2 $k3 $k4");

      List? tl = [];
      List? bl = [];
      List? tr = [];
      List? br = [];

      //print("CLIPLEFT");
      //print("FEATUREINDEX LEN IS ${features.length}");
      List? left  = clip(features, z2, x - k1, x + k3, 0, tile.minX, tile.maxX, options);
      //print("CLIPRIGHT");
      List? right = clip(features, z2, x + k2, x + k4, 0, tile.minX, tile.maxX, options);
      features = [];

      if (left != null && left.isNotEmpty) {
        tl = clip(left, z2, y - k1, y + k3, 1, tile.minY, tile.maxY, options);
        bl = clip(left, z2, y + k2, y + k4, 1, tile.minY, tile.maxY, options);
        left = null;
      }

      if (right != null && right.isNotEmpty) {
        tr = clip(right, z2, y - k1, y + k3, 1, tile.minY, tile.maxY, options);
        br = clip(right, z2, y + k2, y + k4, 1, tile.minY, tile.maxY, options);
        right = null;
      }

      if (debug > 1) print('finished clipping');
      //print("insplit, clip  $tl     $bl     $tr     $br");

      stack.addAll([tl, z + 1, x * 2,     y * 2]);
      stack.addAll([bl, z + 1, x * 2,     y * 2 + 1]);
      stack.addAll([tr, z + 1, x * 2 + 1, y * 2]);
      stack.addAll([br, z + 1, x * 2 + 1, y * 2 + 1]);

      //print("STACK IS $stack");

    }

    print("total ${this.total}, stats ${this.stats}");

  }

  num toID(z, x, y) {
    return (((1 << z) * y + x) * 32) + z;
  }

  SimpTile? getTile(z, x, y) {

    //print("\n\n\ngetTile0");
    //print("TILES! ${this.tiles}");

    Map options = this.options;
    final extent = options['extent'];
    final debug = options['debug'];

    if (z < 0 || z > 24) return null;

    //print("getTile1 $z $x $y");

    final z2 = 1 << z;
    x = (x + z2) & (z2 - 1); // wrap tile x coordinate

    final id = toID(z, x, y);
    if (this.tiles[id] != null) return transformTile(this.tiles[id], extent);

    //print("getTile2 id is $id");

    if (debug > 1) print('drilling down to $z-$x-$y');

    var z0 = z;
    var x0 = x;
    var y0 = y;
    SimpTile? parent;

    while (parent == null && z0 > 0) {
      z0--;
      x0 = x0 >> 1;
      y0 = y0 >> 1;
      parent = this.tiles[toID(z0, x0, y0)];
     // //rint("PARENT IS ${parent!.source}");
    }

    if (parent == null || parent.source == null) return null;

    // if we found a parent tile containing the original geometry, we can drill down from it
    if (debug > 1) {
      //print('found parent tile $z0-$x0-$y0');
      print('drilling down, splitting $z0, $x0, $y0, $z, $x, $y');
    }


    //print("FEATURE LENSOURCE IS ${parent.source.length} ");
    this.splitTile(parent.source, z0, x0, y0, z, x, y);

    if (debug > 1) print('drilling down');

    //print("gettile4 untransformed ${this.tiles[id]}");
    //print("getTile5   ${transformTile(this.tiles[id], extent)}");

    return (this.tiles[id] != null ? transformTile(this.tiles[id], extent) : null);
  }

}

void main () async {
 // var g = GeoJSONVT(geojsonFeature, {'someOption': 1 });
  //print("$g");
  //Slice l = Slice();
  //print("${l.start}");
  List l = [];
  List l2 = [];

  l.start = 2;
  l2.start = 3;
  print("${l.start} ${l2.start}");

  await testGeo();

}

Future<void> testGeo() async {
  var geojsonFeature = {
    "type": "Feature",
    "properties": {
      "name": "Coors Field",
      "amenity": "Baseball Stadium",
      "popupContent": "This is where the Rockies play!"
    },
    "geometry": {
      "type": "Point",
      "coordinates": [-104.99404, 39.75621]
    }
  };

  String geojsonNestedGeometryCollection = """{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {"name": "collection"},
      "geometry": {
        "type": "GeometryCollection",
        "geometries": [
          {
            "type": "GeometryCollection",
            "geometries": [
              {
                "type": "Point",
                "coordinates": [0, 0]
              },
              {
                "type": "Point",
                "coordinates": [1, 1]
              }
            ]
          },
          {
            "type": "Point",
            "coordinates": [0, 0]
          }
        ]
      }
    }
  ]
}""";
  String geojsonPoint = """{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {"name": "point"},
      "geometry": {
        "type": "Point",
        "coordinates": [0, 0]
      }
    }
  ]
}""";
  String geojsonMultiPoint = """{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": {
        "type": "MultiPoint",
        "coordinates": [[0, 0],[0, 0]] 
      }
    }
  ]
}""";
  String geojsonLine = """{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {"nameprop": "line"},
      "geometry": {
        "type": "LineString",
        "coordinates": [
          [4e6, -2e6],
          [8e6, 2e6]
        ]
      }
    }
  ]
}""";
  String geojsonMultiLine = """{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": {
        "type": "MultiLineString",
        "coordinates": [
          [
            [-1e6, -7.5e5],
            [-1e6, 7.5e5]
          ],
          [
            [1e6, -7.5e5],
            [1e6, 7.5e5]
          ],
          [
            [-7.5e5, -1e6],
            [7.5e5, -1e6]
          ],
          [
            [-7.5e5, 1e6],
            [7.5e5, 1e6]
          ]
        ]
      }
    }
  ]
}""";
  String geojsonPolygon = """{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          [
            [-5e6, -1e6],
            [-4e6, 1e6],
            [-3e6, -1e6]
          ]
        ]
      }
    }
  ]
}""";
  String geojsonMultiPolygon = """{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-5e6, 6e6],
              [-5e6, 8e6],
              [-3e6, 8e6],
              [-3e6, 6e6]
            ]
          ],
          [
            [
              [-2e6, 6e6],
              [-2e6, 8e6],
              [0, 8e6],
              [0, 6e6]
            ]
          ],
          [
            [
              [1e6, 6e6],
              [1e6, 8e6],
              [3e6, 8e6],
              [3e6, 6e6]
            ]
          ]
        ]
      }
    }
  ]
}""";

  String geojsonUnsupported = """{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {"name": "point"},
      "geometry": {
        "type": "Unknown",
        "coordinates": [0, 0]
      }
    }
  ]
}""";

  var geoExample = {
    "type": "FeatureCollection",
    "features": [
      {
        "type": "Feature",
        "geometry": {
          "type": "LineString",
          "coordinates": [
            [102.0, 0.0], [103.0, 1.0], [104.0, 0.0], [105.0, 1.0]
          ]
        },
        "properties": {
          "prop0": "value0",
          "prop1": 0.0
        }
      },

      {
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": [102.0, 0.5]
        },
        "properties": {
          "prop0": "value0"
        }
      },
      {
        "type": "Feature",
        "geometry": {
          "type": "LineString",
          "coordinates": [
            [102.0, 0.0], [103.0, 1.0], [104.0, 0.0], [105.0, 1.0]
          ]
        },
        "properties": {
          "prop0": "value0",
          "prop1": 0.0
        }
      },
      {
        "type": "Feature",
        "geometry": {
          "type": "Polygon",
          "coordinates": [
            [
              [100.0, 0.0], [101.0, 0.0], [101.0, 1.0],
              [100.0, 1.0], [100.0, 0.0]
            ]
          ]
        },
        "properties": {
          "prop0": "value0",
          "prop1": { "this": "that" }
        }
      }
    ]
  };

  //var geoTestJsonString = jsonEncode(geoExample);

  //var f = GeoJSONFeatureCollection.fromMap(geoExample);
  //print("$f");

  //List l = [1,2,3];
  //l.size=4;
  //print("${l.size}");

  //var g = GeoJSONVT(geoExample, {'someOption': 1 });
}

Map extend(Map dest, Map src) {
  //print("EXTENDING!!!");
  src.forEach((key, value) {
    dest[key] = src[key];
  });
 // print("EXT $dest");
  return dest;
}



