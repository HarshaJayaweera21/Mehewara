import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/report_model.dart';
import '../../../services/location/location_service.dart';
import '../../../services/reports/report_service.dart';
import '../../../widgets/common/civic_header.dart';
import '../../auth/auth_widgets.dart';

class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({super.key, this.onReportCreated});

  final VoidCallback? onReportCreated;

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  final _picker = ImagePicker();
  final _service = ReportService();
  final List<XFile> _photos = [];
  final Map<String, Future<Uint8List>> _photoBytes = {};

  LatLng _location = LocationService.defaultLocation;
  String _category = 'ROAD';
  bool _submitting = false;
  bool _locating = false;
  bool _locationSelected = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _useLocation() async {
    setState(() => _locating = true);
    final location = await LocationService.getCurrentLocation();
    if (!mounted) return;

    setState(() {
      _locating = false;
      if (location != null) {
        _location = location;
        _locationSelected = true;
      }
    });

    if (location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location is unavailable. Select the pin manually on the map.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _addPhotos(ImageSource source) async {
    final remaining = 5 - _photos.length;
    if (remaining <= 0) return;

    try {
      if (source == ImageSource.camera) {
        final image = await _picker.pickImage(
          source: source,
          imageQuality: 80,
          maxWidth: 1600,
        );
        if (!mounted || image == null) return;
        setState(() {
          _photos.add(image);
          _photoBytes[image.path] = image.readAsBytes();
        });
      } else {
        final images = await _picker.pickMultiImage(
          imageQuality: 80,
          maxWidth: 1600,
        );
        if (!mounted || images.isEmpty) return;
        setState(() {
          final selected = images.take(remaining).toList();
          _photos.addAll(selected);
          for (final image in selected) {
            _photoBytes[image.path] = image.readAsBytes();
          }
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not add photo: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _choosePhotoSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Incident Evidence',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: CivicColors.forest),
                title: const Text('Choose from Photos Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined, color: CivicColors.forest),
                title: const Text('Take a New Photo with Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
    if (source != null) await _addPhotos(source);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!_locationSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose an approximate location on the map or use your current location.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _submitting = true);

    try {
      final uploads = <ReportPhoto>[];
      for (final photo in _photos) {
        uploads.add(await _service.uploadPhoto(photo.path));
      }

      await _service.createReport(
        description: '${_title.text.trim()}\n\n${_description.text.trim()}',
        category: _category,
        latitude: _location.latitude,
        longitude: _location.longitude,
        address: _address.text,
        photos: uploads,
      );

      if (!mounted) return;
      _formKey.currentState!.reset();
      _title.clear();
      _description.clear();
      _address.clear();
      setState(() {
        _category = 'ROAD';
        _photos.clear();
        _photoBytes.clear();
        _locationSelected = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Report submitted successfully. We will keep you updated.'),
            ],
          ),
          backgroundColor: CivicColors.forest,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      widget.onReportCreated?.call();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F4),
      appBar: const CivicHeader(
        title: 'Report Community Issue',
        subtitle: 'Municipal Public Works',
      ),
      body: CivicAtmosphericBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        wide ? 32 : 16,
                        16,
                        wide ? 32 : 16,
                        40,
                      ),
                      children: [
                        // 1. Header Banner
                        const _ReportHeader(),
                        const SizedBox(height: 20),

                        // 2. Form Cards Layout (Split on wide screens)
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 6, child: _buildDetailsCard()),
                              const SizedBox(width: 20),
                              Expanded(flex: 5, child: _buildLocationCard()),
                            ],
                          )
                        else ...[
                          _buildDetailsCard(),
                          const SizedBox(height: 16),
                          _buildLocationCard(),
                        ],
                        const SizedBox(height: 16),

                        // 3. Evidence Photos Card
                        _buildEvidenceCard(),
                        const SizedBox(height: 24),

                        // 4. Submit Action
                        Align(
                          alignment: wide ? Alignment.centerRight : Alignment.center,
                          child: SizedBox(
                            width: wide ? 260 : double.infinity,
                            height: 52,
                            child: FilledButton.icon(
                              onPressed: _submitting ? null : _submit,
                              icon: _submitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded, size: 20),
                              label: Text(
                                _submitting ? 'Submitting Report…' : 'Submit report',
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: CivicColors.forest,
                                foregroundColor: Colors.white,
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Your report will be automatically triaged with AI assistance and routed to the municipal council.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: CivicColors.slateGreen,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    const categories = [
      ('ROAD', 'Road', Icons.construction_outlined),
      ('DRAINAGE', 'Drainage', Icons.water_drop_outlined),
      ('WASTE', 'Waste', Icons.delete_sweep_outlined),
      ('ELECTRICAL', 'Electrical', Icons.electric_bolt_outlined),
      ('ENVIRONMENT', 'Environment', Icons.park_outlined),
    ];

    return CivicSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: CivicColors.mintTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  color: CivicColors.forest,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tell us what you noticed',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: CivicColors.charcoal,
                      ),
                    ),
                    Text(
                      'Provide clear details to help response squads evaluate the issue.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: CivicColors.slateGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          const Text(
            'SELECT ISSUE CATEGORY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: CivicColors.slateGreen,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),

          // Interactive Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((cat) {
                final isSelected = _category == cat.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: Icon(
                      cat.$3,
                      size: 16,
                      color: isSelected ? CivicColors.forest : CivicColors.slateGreen,
                    ),
                    label: Text(cat.$2),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? CivicColors.forest : CivicColors.charcoal,
                    ),
                    selected: isSelected,
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => _category = cat.$1);
                    },
                    selectedColor: CivicColors.mintTint,
                    backgroundColor: const Color(0xFFF9FBF9),
                    side: BorderSide(
                      color: isSelected ? CivicColors.forest : const Color(0xFFE2E8E4),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),

          // Short Title Field
          TextFormField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 100,
            decoration: InputDecoration(
              labelText: 'Issue Title',
              hintText: 'e.g., Deep pothole causing vehicle congestion',
              prefixIcon: const Icon(Icons.title_rounded, size: 20),
              filled: true,
              fillColor: const Color(0xFFF9FBF9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFDDE2DE)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFDDE2DE)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: CivicColors.forest, width: 1.5),
              ),
            ),
            validator: (value) =>
                value == null || value.trim().length < 4
                    ? 'Add a short title (at least 4 characters).'
                    : null,
          ),
          const SizedBox(height: 8),

          // Description Field
          TextFormField(
            controller: _description,
            maxLines: 5,
            maxLength: 1800,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Detailed Observations',
              alignLabelWithHint: true,
              hintText: 'Describe the danger, exact location cues, and severity.',
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 82),
                child: Icon(Icons.notes_rounded, size: 20),
              ),
              filled: true,
              fillColor: const Color(0xFFF9FBF9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFDDE2DE)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFDDE2DE)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: CivicColors.forest, width: 1.5),
              ),
            ),
            validator: (value) =>
                value == null || value.trim().length < 10
                    ? 'Please enter at least 10 characters.'
                    : null,
          ),
          const SizedBox(height: 8),

          // Address Field
          TextFormField(
            controller: _address,
            maxLength: 500,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Address or Nearest Landmark (Optional)',
              hintText: 'e.g., Near Viharamahadevi Park main gate',
              prefixIcon: const Icon(Icons.place_outlined, size: 20),
              filled: true,
              fillColor: const Color(0xFFF9FBF9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFDDE2DE)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFDDE2DE)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: CivicColors.forest, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return CivicSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: CivicColors.mintTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: CivicColors.forest,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pin the location',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: CivicColors.charcoal,
                      ),
                    ),
                    Text(
                      'Tap the map or use GPS to mark the problem.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: CivicColors.slateGreen,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _locating ? null : _useLocation,
                icon: _locating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: CivicColors.forest,
                        ),
                      )
                    : const Icon(Icons.my_location_rounded, size: 16),
                label: const Text('My Location', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: CivicColors.forest,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Map Container
          SizedBox(
            height: 240,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: _location,
                  initialZoom: 15,
                  onTap: (_, point) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _location = point;
                      _locationSelected = true;
                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.mehewara.mobile',
                  ),
                  if (_locationSelected)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _location,
                          width: 50,
                          height: 50,
                          child: const Icon(
                            Icons.location_pin,
                            size: 48,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: _locationSelected
                  ? CivicColors.mintTint
                  : const Color(0xFFF0F4F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _locationSelected
                    ? CivicColors.mintPip.withValues(alpha: 0.4)
                    : const Color(0xFFDDE2DE),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _locationSelected
                      ? Icons.check_circle_rounded
                      : Icons.touch_app_outlined,
                  size: 16,
                  color: _locationSelected
                      ? CivicColors.forest
                      : CivicColors.slateGreen,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _locationSelected
                        ? 'Location pinned (${_location.latitude.toStringAsFixed(4)}, ${_location.longitude.toStringAsFixed(4)}). Tap map to adjust.'
                        : 'No location selected yet. Tap the map or click "My Location".',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: _locationSelected ? FontWeight.w700 : FontWeight.w500,
                      color: _locationSelected
                          ? CivicColors.forest
                          : CivicColors.slateGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceCard() {
    return CivicSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: CivicColors.mintTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.photo_camera_back_outlined,
                  color: CivicColors.forest,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Evidence Photos (Optional)',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: CivicColors.charcoal,
                      ),
                    ),
                    Text(
                      'Attach up to 5 photos to assist field verification.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: CivicColors.slateGreen,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _photos.length >= 5 ? null : _choosePhotoSource,
                icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                label: Text(
                  _photos.isEmpty ? 'Add Photos' : 'Add More',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: CivicColors.forest,
                  side: const BorderSide(color: Color(0xFFDDE2DE)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (_photos.isEmpty)
            GestureDetector(
              onTap: _choosePhotoSource,
              child: Container(
                height: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FBF9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFDDE2DE),
                    style: BorderStyle.solid,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      size: 22,
                      color: CivicColors.slateGreen,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Tap to capture or upload evidence photos',
                      style: TextStyle(
                        color: CivicColors.slateGreen,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 104,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, index) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: FutureBuilder<Uint8List>(
                        future: _photoBytes[_photos[index].path],
                        builder: (context, snapshot) => snapshot.hasData
                            ? Image.memory(
                                snapshot.data!,
                                width: 104,
                                height: 104,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 104,
                                height: 104,
                                color: const Color(0xFFF9FBF9),
                                alignment: Alignment.center,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: CivicColors.forest,
                                ),
                              ),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _photoBytes.remove(_photos[index].path);
                          _photos.removeAt(index);
                        }),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: const BoxDecoration(
                            color: Colors.black87,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReportHeader extends StatelessWidget {
  const _ReportHeader();

  @override
  Widget build(BuildContext context) {
    return CivicSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  CivicColors.forest,
                  Color(0xFF1B4E41),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: CivicColors.forest.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.campaign_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report a Community Issue',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: CivicColors.forest,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Submit hazards, road issues, drainage or sanitation reports for municipal dispatch.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: CivicColors.slateGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
