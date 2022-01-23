import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as dartui;


import 'package:flutter/material.dart';
//import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

import 'package:flutter/services.dart' show rootBundle;

import 'package:geojson_vt_dart/index.dart';
import '../widgets/drawer.dart';

import 'package:flutter_map/plugin_api.dart';
import 'package:tuple/tuple.dart';

class PositionInfo {
  CustomPoint point;
  double width;
  double height;
  String coordsKey;
  double scale;
  PositionInfo({required this.point, required this.width, required this.height, required this.coordsKey, required this.scale});

  @override
  String toString() {
    return 'point:$point width:$width height:$height coordsKey:$coordsKey scale:$scale';
  }

}

class Coords<T extends num> extends CustomPoint<T> {
  late T z;

  Coords(T x, T y) : super(x, y);

  @override
  String toString() => 'Coords($x, $y, $z)';

  @override
  bool operator ==(dynamic other) {
    if (other is Coords) {
      return x == other.x && y == other.y && z == other.z;
    }
    return false;
  }

  @override
  int get hashCode => hashValues(x.hashCode, y.hashCode, z.hashCode);
}

class TileState {

  final Map<double, Level> _levels = {};
  Level _level = Level();
  final mapState;
  double _tileZoom = 12;
  double maxZoom = 20;
  CustomPoint tileSize;

  Tuple2<double, double>? _wrapX;
  Tuple2<double, double>? _wrapY;
  ///late Bounds _globalTileRange;

  TileState(this.mapState, this.tileSize) {
    //_updateLevels();
    //print("VEC SET VIEW ${mapState.center}   ${mapState.zoom}");
    _setView(mapState.center, mapState.zoom);
  }

  double getZoomScale(double zoom, [crs]) {
    crs ??= const Epsg3857();
    return crs.scale(zoom) / crs.scale(zoom);
  }

  Bounds getTiledPixelBounds(MapState mapState) {
    var scale = mapState.getZoomScale(mapState.zoom, _tileZoom);
    var pixelCenter = mapState.project(mapState.center, _tileZoom).floor();
    //print("VEC CENTER $pixelCenter $scale mapcenter is ${mapState.center}   ${mapState.zoom} $_tileZoom");
    var halfSize = mapState.size / (scale * 2);
    return Bounds(pixelCenter - halfSize, pixelCenter + halfSize);
  }

  Bounds pxBoundsToTileRange(Bounds bounds,[tileSize = 256]) {
    final tsPoint = CustomPoint(tileSize,tileSize);
    return Bounds(
      bounds.min.unscaleBy(tsPoint).floor(),
      bounds.max.unscaleBy(tsPoint).ceil() - const CustomPoint(1, 1),
    );
  }

  CustomPoint _getTilePos(Coords coords, tileSize) {
    var level = _levels[coords.z];
    //print("LEVELxz IS $level for z ${coords.z}, levels are $_levels");
    return coords.scaleBy(tileSize) - level!.origin!;
  }

  Bounds getBounds() => getTiledPixelBounds(mapState);

  Bounds getTileRange() => pxBoundsToTileRange(getBounds(),256);

  void _setView(LatLng center, double zoom) {
    var tileZoom = zoom.roundToDouble();
    //if (_tileZoom != tileZoom) {
      _tileZoom = tileZoom;
      //_updateLevels();
      _resetGrid();
    //}

    _updateLevels();

    _setZoomTransforms(center, zoom);
  }

  void _resetGrid() {
    var map = mapState;
    var crs = map.options.crs;
    var tileSize = getTileSize();
    var tileZoom = _tileZoom;

    ///var bounds = map.getPixelWorldBounds(_tileZoom);
    ///if (bounds != null) {
    ///  _globalTileRange = pxBoundsToTileRange(bounds);
    ///}

    // wrapping
    _wrapX = crs.wrapLng;
    if (_wrapX != null) {
      var first = (map.project(LatLng(0.0, crs.wrapLng!.item1), tileZoom).x /
          tileSize.x)
          .floorToDouble();
      var second = (map.project(LatLng(0.0, crs.wrapLng!.item2), tileZoom).x /
          tileSize.y)
          .ceilToDouble();
      _wrapX = Tuple2(first, second);
    }

    _wrapY = crs.wrapLat;
    if (_wrapY != null) {
      var first = (map.project(LatLng(crs.wrapLat!.item1, 0.0), tileZoom).y /
          tileSize.x)
          .floorToDouble();
      var second = (map.project(LatLng(crs.wrapLat!.item2, 0.0), tileZoom).y /
          tileSize.y)
          .ceilToDouble();
      _wrapY = Tuple2(first, second);
    }
  }



  void _setZoomTransforms(LatLng center, double zoom) {
    for (var i in _levels.keys) {
      _setZoomTransform(_levels[i]!, center, zoom);
    }
  }

  void _setZoomTransform(Level level, LatLng center, double zoom) {
    var scale = mapState.getZoomScale(zoom, level.zoom);
    var pixelOrigin = mapState.getNewPixelOrigin(center, zoom).round();
    if (level.origin == null) {
      return;
    }
    var origin = level.origin;
    if (origin != null) {
      var translate = origin.multiplyBy(scale) - pixelOrigin;
      level.translatePoint = translate;
      level.scale = scale;
    }
  }

  void _updateLevels() {
    var zoom = _tileZoom;

    //print("1");
    //print("LEVELS $_levels");

    for (var z in _levels.keys) {
      //print("Checking level $z ${_levels[z]}");
      var levelZ = _levels[z];
      if(levelZ != null) {
        if (z == zoom) { /// recheck here.....
          var levelZi = _levels[z];
          if (levelZi != null) {
            levelZi.zIndex = maxZoom = (zoom - z).abs();
          }
        }
      }
    }

    //print("2");

    var max = maxZoom + 2; // arbitrary, was originally for overzoom

    for(var tempZoom in [for(var i=1.0; i<max; i+=1.0) i]) {

      //print("checking $tempZoom");

      var level = _levels[tempZoom];
      var map = mapState;

      if (level == null) {

        //print("Level $tempZoom is null....");

        level = _levels[tempZoom.toDouble()] = Level();
        level.zIndex = maxZoom;
        var newOrigin = map.project(map.unproject(map.getPixelOrigin()), tempZoom);
        level.origin = newOrigin;
        level.zoom = tempZoom;
        //print("level is now ${level.origin}");
        _setZoomTransform(level, map.center, map.zoom);
      }

    }

    //print("3");

    var levelZoom = _levels[zoom];
    if(levelZoom != null)
      _level = levelZoom;

  }

/*
  void _setZoomTransform(Level level, LatLng center, double zoom) {
    var scale = mapState.getZoomScale(zoom, level.zoom);
    var pixelOrigin = mapState.getNewPixelOrigin(center, zoom).round();
    if (level.origin == null) {
      return;
    }
    var origin = level.origin;
    if( origin != null) {
      var translate = origin.multiplyBy(scale) - pixelOrigin;
      level.translatePoint = translate;
      level.scale = scale;
    }
  }


 */
  PositionInfo getTilePositionInfo( double z, double x, double y ) {
    var coords = Coords(x,y);
    coords.z = z.floorToDouble();

    var tilePos = _getTilePos(coords, tileSize);
    var level = _levels[coords.z];

    var scale = level?.scale ?? 1;
    var pos = (tilePos).multiplyBy(scale) + level!.translatePoint;
    var width = (tileSize.x * scale);
    var height = tileSize.y * scale;
    var coordsKey = tileCoordsToKey(coords);

    ///return [pos, scale, coordsKey];
    return PositionInfo(point: pos, width: width, height: height, coordsKey: coordsKey, scale: width / tileSize.x );

    //return tilePositionInfo;

  }

  String tileCoordsToKey(Coords coords) {
    return '${coords.x}:${coords.y}:${coords.z}';
  }

  CustomPoint getTileSize() {
    return tileSize;
  }

  double getTileZoom() {
    return _tileZoom;
  }
}

class VectorPainter extends CustomPainter with ChangeNotifier {

  //ValueNotifier<int> notifier;
  final Stream<Null>? stream;
  GeoJSONVT? index;
  MapState mapState;
  //int notifier;
  TileState? tileState;
  Paint defaultStyle = Paint()
    ..style = PaintingStyle.stroke
    ..color = Colors.red
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = false;

  VectorPainter({ required this.mapState, this.index, this.stream });

  //void update() {
  //  notifyListeners();
  //}

  @override
  void paint(Canvas canvas, Size size) {

    Bounds _tileRange;
    final List featuresInView = [];

    var origin = mapState.getPixelOrigin();
    //print("ORIGIN IS $origin!!!!!!!!!!!");

    tileState = TileState(mapState, CustomPoint(256.0, 256.0));


    //var tilePos = Coords()

    //print("Zoom: ${mapState.zoom} Index: ${index} :FIN");
    //var bounds = getTiledPixelBounds(mapState);
    //_tileRange = pxBoundsToTileRange(bounds,256);
    _tileRange = tileState!.getTileRange();
    //print("Tilerange $_tileRange");

    //print("START!!!!!!!!! $_tileRange");
    //print("VEC BOUNDS ${tileState!.getBounds()}");
    for (var j = _tileRange.min.y; j <= _tileRange.max.y; j++) {
      for (var i = _tileRange.min.x; i <= _tileRange.max.x; i++) {
        //print('tile Z${tileState!.getTileZoom()} $i $j  ');
        var tile = index?.getTile(tileState!.getTileZoom().toInt(), i, j);
        //print("${tile.features}")

        final List featuresInView = [];

        if(tile != null && tile.features.isNotEmpty) {
          featuresInView.addAll(tile.features);
        }

        var pos = tileState!.getTilePositionInfo(tileState!.getTileZoom(), i.toDouble(), j.toDouble());
        //print("POS IS $pos, zoom is ${mapState.zoom}");

        Matrix4 matrix = Matrix4.identity();
        if(pos != null) {
          matrix
            ..translate(pos.point.x.toDouble(), pos.point.y.toDouble())
            ..scale(pos.scale);
        }
        canvas.save();
        canvas.transform(matrix.storage);
        var myRect = Offset(0,0) & Size(256.0,256.0);
        canvas.clipRect(myRect);

        var p = dartui.Path();

        for (var feature in featuresInView) {
          if( feature['type'] == 3) {
            //var g = feature['geometry'];
            for( var item in feature['geometry'] ) {

             // print("ITEM IS $item");
              p.moveTo(item[0][0].toDouble(), item[0][1].toDouble());
              for (var c = 1; c < item.length; c++) {
                p.lineTo(item[c][0].toDouble(), item[c][1].toDouble());
               // print("$c ${item[c]}");
              }
            }
          }
        }
        //print("drawing path $p");
        canvas.drawPath(p, defaultStyle);


        canvas.restore();

        //if(o != null) {
        //print("tilexx $tile   posInfo = $pos");
        //}
      }
    }
/*
    print("FEATURES ARE $featuresInView");
    for(var feature in featuresInView) {
      print('${feature['type']}');
      if( feature['type'] == 3) {

      }
    }


 */
  }

  @override
  bool shouldRepaint(VectorPainter oldDelegate) => true;
}

class SliceLayerWidget extends StatefulWidget {
  //final SliceLayerOptions options;
  final GeoJSONVT? index;

  SliceLayerWidget({Key? key, this.index}) : super(key: key); // : super(key: key);

  @override
  _SliceLayerWidgetState createState() => _SliceLayerWidgetState();
}

class _SliceLayerWidgetState extends State<SliceLayerWidget> {

  //ValueNotifier<int> notifier = ValueNotifier(0);

  @override
  Widget build(BuildContext context) {

    //print("buildxxx ${notifier.value}");

    //print("SLICER BUILD!");

    //notifier.value++;
    final mapState = MapState.maybeOf(context)!;

    var width = MediaQuery.of(context).size.width * 2.0;
    var height = MediaQuery.of(context).size.height;
    var dimensions = Offset(width,height);



    return StreamBuilder<void>(
      stream: mapState.onMoved,
      builder: (BuildContext context, _) {

        var box = SizedBox(
            width: width*1.25, /// calculate this properly depending on rotation and mobile orientation
            height: height*1.25,
            child: RepaintBoundary (
                child: CustomPaint(
                    isComplex: true, //Tells flutter to cache the painter.
                    painter: VectorPainter(mapState: mapState, index: widget.index, stream: mapState.onMoved)
                )
            )
        );
        return box;
      }
    );

    //return box;
    //return Text("hi");
  }
}




class MapControllerPage extends StatefulWidget {
  static const String route = 'map_controller';

  @override
  MapControllerPageState createState() {
    return MapControllerPageState();
  }
}

class MapControllerPageState extends State<MapControllerPage> {
  static LatLng london = LatLng(51.5, -0.09);
  static LatLng paris = LatLng(48.8566, 2.3522);
  static LatLng dublin = LatLng(53.3498, -6.2603);

  late final MapController mapController;
  double rotation = 0.0;
  GeoJSONVT? geoJson;
  List<Marker> markers = [];

  @override
  void initState() async {
    super.initState();
    mapController = MapController();

    markers = <Marker>[
      Marker(
        width: 80.0,
        height: 80.0,
        point: london,
        builder: (ctx) => Container(
          key: Key('blue'),
          child: FlutterLogo(),
        ),
      ),
      Marker(
        width: 80.0,
        height: 80.0,
        point: dublin,
        builder: (ctx) => Container(
          child: FlutterLogo(
            key: Key('green'),
            textColor: Colors.green,
          ),
        ),
      ),
      Marker(
        width: 80.0,
        height: 80.0,
        point: paris,
        builder: (ctx) => Container(
          key: Key('purple'),
          child: FlutterLogo(textColor: Colors.purple),
        ),
      ),
    ];

    WidgetsBinding.instance!.addPostFrameCallback((_) async {
      var json = jsonDecode(await rootBundle.loadString('assets/us-states.json'));
      print("JSON IS $json");

      geoJson = GeoJSONVT(json, {
        'debug' : 0,
        'buffer' : 64,
        'indexMaxZoom': 20,
        'indexMaxPoints': 10000000,
        'tolerance' : 0,
        'extent': 256.0});
      print("VT DONE $geoJson");
      print("gt ${geoJson?.getTile(0,0,0)}");
      print("gt2 ${geoJson?.getTile(5,9,15)}");
      setState(() { });
    });
  }

  @override
  Widget build(BuildContext context) {

    print("Build geojson $geoJson");
    //print("${mapController.bounds}");
    /*
    var markers = <Marker>[
      Marker(
        width: 80.0,
        height: 80.0,
        point: london,
        builder: (ctx) => Container(
          key: Key('blue'),
          child: FlutterLogo(),
        ),
      ),
      Marker(
        width: 80.0,
        height: 80.0,
        point: dublin,
        builder: (ctx) => Container(
          child: FlutterLogo(
            key: Key('green'),
            textColor: Colors.green,
          ),
        ),
      ),
      Marker(
        width: 80.0,
        height: 80.0,
        point: paris,
        builder: (ctx) => Container(
          key: Key('purple'),
          child: FlutterLogo(textColor: Colors.purple),
        ),
      ),
    ];

     */

    return Scaffold(
      appBar: AppBar(title: Text('MapController')),
      drawer: buildDrawer(context, MapControllerPage.route),
      body: Padding(
        padding: EdgeInsets.all(8.0),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
              child: Row(
                children: <Widget>[
                  MaterialButton(
                    onPressed: () {
                      mapController.move(london, 18.0);
                    },
                    child: Text('London'),
                  ),
                  MaterialButton(
                    onPressed: () {
                      mapController.move(paris, 5.0);
                    },
                    child: Text('Paris'),
                  ),
                  MaterialButton(
                    onPressed: () {
                      mapController.move(dublin, 5.0);
                    },
                    child: Text('Dublin'),
                  ),
                  CurrentLocation(mapController: mapController),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
              child: Row(
                children: <Widget>[
                  MaterialButton(
                    onPressed: () {
                      var bounds = LatLngBounds();
                      bounds.extend(dublin);
                      bounds.extend(paris);
                      bounds.extend(london);
                      mapController.fitBounds(
                        bounds,
                        options: FitBoundsOptions(
                          padding: EdgeInsets.only(left: 15.0, right: 15.0),
                        ),
                      );
                    },
                    child: Text('Fit Bounds'),
                  ),
                  Builder(builder: (BuildContext context) {
                    return MaterialButton(
                      onPressed: () {
                        final bounds = mapController.bounds!;

                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                            'Map bounds: \n'
                            'E: ${bounds.east} \n'
                            'N: ${bounds.north} \n'
                            'W: ${bounds.west} \n'
                            'S: ${bounds.south}',
                          ),
                        ));
                      },
                      child: Text('Get Bounds'),
                    );
                  }),
                  Text('Rotation:'),
                  Expanded(
                    child: Slider(
                      value: rotation,
                      min: 0.0,
                      max: 360,
                      onChanged: (degree) {
                        setState(() {
                          rotation = degree;
                        });
                        mapController.rotate(degree);
                      },
                    ),
                  )
                ],
              ),
            ),
            Flexible(
              child: FlutterMap(

                mapController: mapController,
                options: MapOptions(
                    onTap: (tapPos, LatLng latLng) {
                      print("TAP $tapPos    $latLng");
                      markers.add(
                        Marker(
                          point: latLng,
                          builder: (ctx) => Icon(Icons.favorite),

                        ),
                      );
                      setState(() {

                      });
                    },
                  center: LatLng(51.5, -0.09),
                  zoom: 5.0,
                  maxZoom: 15.0,
                  minZoom: 0.0,
                    //interactiveFlags: InteractiveFlag.all & ~InteractiveFlag.rotate
                ),
                layers: [
                  TileLayerOptions(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: ['a', 'b', 'c']),
                  MarkerLayerOptions(markers: markers),
                  //LayerOptions(),
                  //SliceLayer(options: SliceLayerOptions(), index: geoJson,)
                ],
                nonRotatedChildren: <Widget>[
                  SliceLayerWidget(index: geoJson)
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CurrentLocation extends StatefulWidget {
  const CurrentLocation({
    Key? key,
    required this.mapController,
  }) : super(key: key);

  final MapController mapController;

  @override
  _CurrentLocationState createState() => _CurrentLocationState();
}

class _CurrentLocationState extends State<CurrentLocation> {
  int _eventKey = 0;

  var icon = Icons.gps_not_fixed;
  late final StreamSubscription<MapEvent> mapEventSubscription;

  @override
  void initState() {
    super.initState();

    mapEventSubscription =
        widget.mapController.mapEventStream.listen(onMapEvent);
  }

  @override
  void dispose() {
    mapEventSubscription.cancel();
    super.dispose();
  }

  void setIcon(IconData newIcon) {
    if (newIcon != icon && mounted) {
      setState(() {
        icon = newIcon;
      });
    }
  }

  void onMapEvent(MapEvent mapEvent) {
    if (mapEvent is MapEventMove && mapEvent.id == _eventKey.toString()) {
      setIcon(Icons.gps_not_fixed);
    }
  }

  void _moveToCurrent() async {
    _eventKey++;
    var location = Location();

    try {
      var currentLocation = await location.getLocation();
      var moved = widget.mapController.move(
        LatLng(currentLocation.latitude!, currentLocation.longitude!),
        18,
        id: _eventKey.toString(),
      );

      if (moved) {
        setIcon(Icons.gps_fixed);
      } else {
        setIcon(Icons.gps_not_fixed);
      }
    } catch (e) {
      setIcon(Icons.gps_off);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      onPressed: _moveToCurrent,
    );
  }
}
