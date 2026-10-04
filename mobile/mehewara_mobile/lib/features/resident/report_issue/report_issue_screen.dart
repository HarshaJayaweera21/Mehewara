import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/report_model.dart';
import '../../../services/location/location_service.dart';
import '../../../services/reports/report_service.dart';

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
        const SnackBar(content: Text('Location is unavailable. Select the pin manually on the map.')),
      );
    }
  }

  Future<void> _addPhotos(ImageSource source) async {
    final remaining = 5 - _photos.length;
    if (remaining <= 0) return;

    try {
      if (source == ImageSource.camera) {
        final image = await _picker.pickImage(source: source, imageQuality: 80, maxWidth: 1600);
        if (!mounted || image == null) return;
        setState(() {
          _photos.add(image);
          _photoBytes[image.path] = image.readAsBytes();
        });
      } else {
        final images = await _picker.pickMultiImage(imageQuality: 80, maxWidth: 1600);
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not add photo: $error')));
    }
  }

  Future<void> _choosePhotoSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose from photos'), onTap: () => Navigator.pop(context, ImageSource.gallery)),
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take a photo'), onTap: () => Navigator.pop(context, ImageSource.camera)),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (source != null) await _addPhotos(source);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_locationSelected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose an approximate location on the map or use your current location.')));
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
        const SnackBar(content: Text('Report submitted. We will keep you updated.')),
      );
      widget.onReportCreated?.call();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CivicColors.alabaster,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(wide ? 32 : 16, 16, wide ? 32 : 16, 32),
                    children: [
                      const _ReportHeader(),
                      const SizedBox(height: 20),
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
                      _buildEvidenceCard(),
                      const SizedBox(height: 24),
                      Align(
                        alignment: wide ? Alignment.centerRight : Alignment.center,
                        child: SizedBox(
                          width: wide ? 240 : double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _submitting ? null : _submit,
                            icon: _submitting
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.send_rounded),
                            label: Text(_submitting ? 'Submitting…' : 'Submit report'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Share only what the response team needs. Photos and address details are optional.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: CivicColors.slateGreen),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    return _FormCard(
      icon: Icons.edit_note_rounded,
      title: 'Tell us what you noticed',
      subtitle: 'A clear description helps the municipal team assess the report.',
      child: Column(
        children: [
          Align(alignment: Alignment.centerLeft, child: Text('Issue category', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700))),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final item in const [('ROAD', 'Road'), ('DRAINAGE', 'Drainage'), ('WASTE', 'Waste'), ('ELECTRICAL', 'Electrical'), ('ENVIRONMENT', 'Environment')])
              ChoiceChip(label: Text(item.$2), selected: _category == item.$1, onSelected: (_) => setState(() => _category = item.$1), selectedColor: CivicColors.mintTint),
          ]),
          const SizedBox(height: 14),
          TextFormField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Short title', hintText: 'e.g. Blocked drain near the park'),
            validator: (value) => value == null || value.trim().length < 4 ? 'Add a short title (at least 4 characters).' : null,
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _description,
            maxLines: 6,
            maxLength: 1800,
            decoration: const InputDecoration(
              labelText: 'What happened?',
              alignLabelWithHint: true,
              hintText: 'Describe what you observed, the risk, and who is affected.',
            ),
            validator: (value) => value == null || value.trim().length < 10 ? 'Please enter at least 10 characters.' : null,
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: _address,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Address or landmark', hintText: 'Optional, but helpful'),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return _FormCard(
      icon: Icons.location_on_outlined,
      title: 'Pin the location',
      subtitle: 'Select an approximate location. You can move the pin before submitting.',
      action: TextButton.icon(
        onPressed: _locating ? null : _useLocation,
        icon: _locating
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.my_location_rounded, size: 18),
        label: const Text('Use my location'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 236,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: _location,
                  initialZoom: 15,
                  onTap: (_, point) => setState(() {
                    _location = point;
                    _locationSelected = true;
                  }),
                ),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.mehewara.mobile'),
                  if (_locationSelected) MarkerLayer(
                    markers: [
                      Marker(
                        point: _location,
                        width: 46,
                        height: 46,
                        child: const Icon(Icons.location_pin, size: 44, color: Colors.red),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: CivicColors.surfaceSubtle, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Icon(_locationSelected ? Icons.location_on_outlined : Icons.touch_app_outlined, size: 16, color: CivicColors.slateGreen),
                const SizedBox(width: 8),
                Expanded(child: Text(_locationSelected ? 'Approximate area selected. Tap the map to adjust.' : 'No location selected yet. Tap the map or use your location.', style: const TextStyle(fontSize: 12, color: CivicColors.slateGreen))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceCard() {
    return _FormCard(
      icon: Icons.photo_camera_back_outlined,
      title: 'Add photos',
      subtitle: 'Optional — attach up to five photos as supporting evidence.',
      action: OutlinedButton.icon(
        onPressed: _photos.length >= 5 ? null : _choosePhotoSource,
        icon: const Icon(Icons.add_a_photo_outlined, size: 18),
        label: Text(_photos.isEmpty ? 'Add photos' : 'Add more'),
      ),
      child: _photos.isEmpty
          ? Container(
              height: 80,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: CivicColors.surfaceSubtle, borderRadius: BorderRadius.circular(10), border: Border.all(color: CivicColors.borderSubtle)),
              child: const Text('No photos selected', style: TextStyle(color: CivicColors.slateGreen)),
            )
          : SizedBox(
              height: 102,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, index) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: FutureBuilder<Uint8List>(
                        future: _photoBytes[_photos[index].path],
                        builder: (context, snapshot) => snapshot.hasData
                            ? Image.memory(snapshot.data!, width: 102, height: 102, fit: BoxFit.cover)
                            : Container(width: 102, height: 102, color: CivicColors.surfaceSubtle, alignment: Alignment.center, child: const CircularProgressIndicator(strokeWidth: 2)),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: IconButton.filledTonal(
                        style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: CivicColors.charcoal),
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => setState(() {
                          _photoBytes.remove(_photos[index].path);
                          _photos.removeAt(index);
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ReportHeader extends StatelessWidget {
  const _ReportHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: CivicColors.forest,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [CivicShadows.card],
      ),
      child: const Row(
        children: [
          CircleAvatar(radius: 25, backgroundColor: CivicColors.mintPip, child: Icon(Icons.campaign_outlined, color: CivicColors.forest)),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Report a community issue', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                SizedBox(height: 4),
                Text('Share what you see. We will keep you informed as it progresses.', style: TextStyle(height: 1.35, color: Color(0xFFD9EEE5))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  const _FormCard({required this.icon, required this.title, required this.subtitle, required this.child, this.action});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: CivicColors.mintTint, borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, size: 20, color: CivicColors.forest),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: CivicColors.charcoal)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(fontSize: 12, height: 1.3, color: CivicColors.slateGreen)),
                    ],
                  ),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
