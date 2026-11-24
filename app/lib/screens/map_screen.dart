import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../config.dart';
import '../models/territory.dart';
import '../state/app_scope.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  bool _running = false;
  int? _runId;
  final List<LatLng> _track = [];
  StreamSubscription<Position>? _posSub;
  LatLng? _me;
  bool _starting = false;

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  Color _colorForUser(int userId) {
    final hue = (userId * 137.508) % 360;
    return HSLColor.fromAHSL(0.35, hue, 0.65, 0.45).toColor();
  }

  Color _strokeForUser(int userId) {
    final hue = (userId * 137.508) % 360;
    return HSLColor.fromAHSL(0.9, hue, 0.70, 0.35).toColor();
  }

  List<Polygon> _territoryPolygons(List<Territory> territories, int? myId) {
    final polys = <Polygon>[];
    for (final t in territories) {
      final geom = t.geometry;
      final type = geom['type'];
      final coords = geom['coordinates'];
      final rings = <List<List<dynamic>>>[];
      if (type == 'Polygon' && coords is List) {
        rings.add(List<List<dynamic>>.from(coords));
      } else if (type == 'MultiPolygon' && coords is List) {
        for (final poly in coords) {
          if (poly is List) rings.add(List<List<dynamic>>.from(poly));
        }
      }
      for (final ringSet in rings) {
        if (ringSet.isEmpty) continue;
        final outer = ringSet.first;
        final points = <LatLng>[];
        for (final p in outer) {
          if (p is List && p.length >= 2) {
            points.add(LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()));
          }
        }
        if (points.length < 3) continue;
        final mine = t.userId == myId;
        polys.add(Polygon(
          points: points,
          color: mine ? _colorForUser(t.userId).withOpacity(0.45) : _colorForUser(t.userId),
          borderColor: _strokeForUser(t.userId),
          borderStrokeWidth: mine ? 2.5 : 1.5,
          isFilled: true,
        ));
      }
    }
    return polys;
  }

  Future<bool> _ensureLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Active la localisation GPS.')));
      }
      return false;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permission localisation refusée.')));
      }
      return false;
    }
    return true;
  }

  Future<void> _startRun() async {
    if (_starting || _running) return;
    setState(() => _starting = true);
    final app = AppScope.read(context);
    try {
      if (!await _ensureLocationPermission()) return;
      final res = await app.api.startRun();
      final run = res['run'] as Map<String, dynamic>;
      _runId = run['id'] as int;
      _track.clear();
      _running = true;
      _posSub?.cancel();
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 5),
      ).listen((pos) {
        final p = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _me = p;
          _track.add(p);
        });
        // Batch send every 10 points.
        if (_runId != null && _track.length % 10 == 0) {
          final batch = _track.sublist(_track.length - 10).map((e) => {'lat': e.latitude, 'lng': e.longitude}).toList();
          app.api.sendPoints(_runId!, batch).catchError((_) {});
        }
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Course démarrée. Ferme une boucle pour capturer la zone !')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _finishRun() async {
    if (!_running || _runId == null) return;
    final app = AppScope.read(context);
    final points = _track.map((e) => {'lat': e.latitude, 'lng': e.longitude}).toList();
    try {
      final res = await app.api.finishRun(_runId!, points);
      await _posSub?.cancel();
      setState(() {
        _running = false;
        _runId = null;
        _track.clear();
      });
      await app.refreshData();
      if (!mounted) return;
      final claimed = res['claimed'] == true;
      final msg = claimed
          ? 'Zone capturée ! +${((res['claimedAreaM2'] as num).toDouble() / 10000).toStringAsFixed(2)} ha'
          : (res['reason'] as String? ?? 'Aucune zone capturée.');
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(claimed ? 'Bravo !' : 'Course terminée'),
          content: Text(msg),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _cancelRun() async {
    if (!_running || _runId == null) return;
    final app = AppScope.read(context);
    try {
      await app.api.cancelRun(_runId!);
    } catch (_) {}
    await _posSub?.cancel();
    setState(() {
      _running = false;
      _runId = null;
      _track.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final myId = app.user?.id;
    final polygons = _territoryPolygons(app.territories, myId);

    return Column(
      children: [
        Expanded(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(AppConfig.franceCenterLat, AppConfig.franceCenterLng),
              initialZoom: 6,
              minZoom: 5,
              maxZoom: 18,
              cameraConstraint: CameraConstraint.contain(
                bounds: LatLngBounds(
                  const LatLng(AppConfig.franceMinLat, AppConfig.franceMinLng),
                  const LatLng(AppConfig.franceMaxLat, AppConfig.franceMaxLng),
                ),
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.runningzone.app',
                maxZoom: 19,
              ),
              PolygonLayer(polygons: polygons),
              if (_track.length >= 2)
                PolylineLayer(polylines: [
                  Polyline(points: _track, strokeWidth: 4, color: Colors.blueAccent),
                ]),
              if (_me != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _me!,
                    width: 18,
                    height: 18,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                    ),
                  ),
                ]),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_running)
                  Text('Course en cours • ${_track.length} points • ferme la boucle pour capturer',
                      textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (!_running)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _starting ? null : _startRun,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Démarrer une course'),
                        ),
                      )
                    else ...[
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _finishRun,
                          icon: const Icon(Icons.flag),
                          label: const Text('Terminer & capturer'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _cancelRun,
                        child: const Text('Annuler'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
