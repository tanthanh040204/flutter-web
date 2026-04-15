import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../config/app_constants.dart';
import '../config/app_theme.dart';
import '../models/route_point.dart';
import '../providers/route_provider.dart';
import '../utils/geo_utils.dart';

/// ============================================
/// MAP WIDGET - Hiển thị bản đồ và route
/// ============================================

class MapWidget extends StatefulWidget {
  const MapWidget({super.key});

  @override
  State<MapWidget> createState() => MapWidgetState();
}

class MapWidgetState extends State<MapWidget> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Public method: Fit camera to show all route points
  void fitToRoute() {
    final routeProvider = context.read<RouteProvider>();
    if (routeProvider.hasRoute) {
      _fitBounds(routeProvider.points);
    }
  }

  /// Public method: Center map on a specific location
  void centerOn(LatLng location, {double? zoom}) {
    _mapController.move(location, zoom ?? _mapController.camera.zoom);
  }

  /// Public method: Move to location with animation
  void animateTo(LatLng location, {double? zoom}) {
    _mapController.move(location, zoom ?? _mapController.camera.zoom);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RouteProvider>(
      builder: (context, routeProvider, child) {
        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _getInitialCenter(routeProvider.points),
            initialZoom: MapConfig.defaultZoom,
            minZoom: MapConfig.minZoom,
            maxZoom: MapConfig.maxZoom,
            onMapReady: () {
              if (routeProvider.hasRoute) {
                _fitBounds(routeProvider.points);
              }
            },
          ),
          children: [
            // Tile layer
            TileLayer(
              urlTemplate: MapConfig.cartoDbTileUrl,
              subdomains: MapConfig.subdomains,
              userAgentPackageName: 'com.example.route_tracker',
            ),

            // Route polyline
            if (routeProvider.hasRoute)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routeProvider.points.map((p) => p.latLng).toList(),
                    color: AppColors.routeLine,
                    strokeWidth: RouteConfig.lineWidth,
                  ),
                ],
              ),

            // Markers
            if (routeProvider.hasRoute && routeProvider.showMarkers)
              MarkerLayer(
                markers: _buildMarkers(routeProvider.points),
              ),

            // Attribution
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution(MapConfig.attribution),
              ],
            ),
          ],
        );
      },
    );
  }

  LatLng _getInitialCenter(List<RoutePoint> points) {
    if (points.isEmpty) {
      return const LatLng(
        MapConfig.defaultLatitude,
        MapConfig.defaultLongitude,
      );
    }
    return GeoUtils.calculateCenter(points) ??
        const LatLng(MapConfig.defaultLatitude, MapConfig.defaultLongitude);
  }

  void _fitBounds(List<RoutePoint> points) {
    final bounds = GeoUtils.calculateBounds(points);
    if (bounds != null) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50),
        ),
      );
    }
  }

  List<Marker> _buildMarkers(List<RoutePoint> points) {
    if (points.isEmpty) return [];

    final markers = <Marker>[];

    // Start marker
    markers.add(_buildMarker(
      points.first,
      AppColors.startMarker,
      MarkerConfig.startEndSize,
      Icons.play_arrow,
    ));

    // Middle markers (limit to avoid performance issues)
    if (points.length > 2) {
      final step = points.length > UIConfig.maxDisplayPoints
          ? points.length ~/ UIConfig.maxDisplayPoints
          : 1;

      for (int i = 1; i < points.length - 1; i += step) {
        markers.add(_buildMarker(
          points[i],
          AppColors.normalMarker,
          MarkerConfig.normalSize,
          null,
        ));
      }
    }

    // End marker
    if (points.length > 1) {
      markers.add(_buildMarker(
        points.last,
        AppColors.endMarker,
        MarkerConfig.startEndSize,
        Icons.flag,
      ));
    }

    return markers;
  }

  Marker _buildMarker(
    RoutePoint point,
    Color color,
    double size,
    IconData? icon,
  ) {
    return Marker(
      point: point.latLng,
      width: size,
      height: size,
      child: GestureDetector(
        onTap: () => _showPointInfo(point),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.white,
              width: MarkerConfig.borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: icon != null
              ? Icon(
                  icon,
                  color: AppColors.white,
                  size: size * 0.6,
                )
              : null,
        ),
      ),
    );
  }

  void _showPointInfo(RoutePoint point) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(point.displayName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lat: ${point.latitude.toStringAsFixed(6)}'),
            Text('Lng: ${point.longitude.toStringAsFixed(6)}'),
            if (point.timestamp != null)
              Text('Time: ${point.timestamp!.toLocal()}'),
            if (point.description != null) Text(point.description!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}
