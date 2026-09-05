import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tr.dart';
import '../../../models/car_service_request.dart';
import '../../../models/service_photo.dart';
import '../providers/service_staff_provider.dart';
import 'service_staff_widgets.dart';

class ServicePickupScreen extends StatefulWidget {
  const ServicePickupScreen({super.key});

  @override
  State<ServicePickupScreen> createState() => _ServicePickupScreenState();
}

class _ServicePickupScreenState extends State<ServicePickupScreen> {
  final _picker = ImagePicker();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    context.read<ServiceStaffProvider>().subscribeToActive();
  }

  @override
  void dispose() {
    context.read<ServiceStaffProvider>().unsubscribeActive();
    super.dispose();
  }

  ServiceStaffProvider get _staff => context.read<ServiceStaffProvider>();

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Tr('Take a photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: const Tr('Upload from device'),
              onTap: () => Navigator.pop(context, 'files'),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    setState(() => _busy = true);
    try {
      Uint8List? bytes;
      String name;
      if (source == 'camera') {
        final x = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1600,
          imageQuality: 80,
        );
        if (x == null) return;
        bytes = await x.readAsBytes();
        name = x.name;
      } else {
        final f = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'heic'],
        );
        if (f == null) return;
        bytes = await f.readAsBytes();
        name = f.name;
      }
      final ok = await _staff.addPhoto(
        phase: ServicePhotoPhase.pickup,
        bytes: bytes,
        fileName: name,
      );
      _toast(ok ? 'Photo added' : 'Photo failed to upload');
    } catch (e) {
      _toast('Could not add the photo');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _actionLabel(CarServiceStatus phase) {
    switch (phase) {
      case CarServiceStatus.assigned:
        return 'Mark car picked up';
      case CarServiceStatus.pickedUp:
        return 'Car is in the service centre';
      default:
        return 'Advance';
    }
  }

  Future<void> _advance() async {
    final wasPickedUp = _staff.active?.status == CarServiceStatus.pickedUp;
    setState(() => _busy = true);
    await _staff.advanceStatus();
    if (!mounted) return;
    setState(() => _busy = false);
    if (wasPickedUp && _staff.active?.status == CarServiceStatus.atCentre) {
      _toast('Car marked as at the service centre');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final staff = context.watch<ServiceStaffProvider>();
    final r = staff.active;

    if (r == null) {
      return const Scaffold(body: Center(child: Tr('No job selected')));
    }

    final phase = r.status;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          ScreenHeader(
            eyebrow: _phaseEyebrow(phase),
            title: r.serviceTypesLabel,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, 16, 20, 28 + MediaQuery.viewPaddingOf(context).bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                JobMap(staff: staff, request: r),
                const SizedBox(height: 14),
                CustomerCard(staff: staff, request: r),
                const SizedBox(height: 12),
                VehicleCard(car: staff.activeVehicle),
                const SizedBox(height: 12),
                CentreCard(staff: staff),
                const SizedBox(height: 12),
                PickupCard(request: r),
                const SizedBox(height: 16),

                sectionTitle('PICK-UP PHOTOS'),
                const SizedBox(height: 8),
                PhotoStrip(
                  label: 'Pick-up',
                  photos: staff.photos
                      .where((p) => p.phase == ServicePhotoPhase.pickup)
                      .toList(),
                  onAdd: _addPhoto,
                ),
                const SizedBox(height: 16),

                sectionTitle('PICK-UP PROGRESS'),
                const SizedBox(height: 8),
                StepRow(
                  label: 'Driver assigned',
                  done: true,
                  active: false,
                ),
                StepRow(
                  label: 'Picked up',
                  done: r.pickedUpAt != null,
                  active: phase == CarServiceStatus.assigned,
                ),
                StepRow(
                  label: 'At service centre',
                  done: r.atCentreAt != null,
                  active: phase == CarServiceStatus.pickedUp,
                ),
                const SizedBox(height: 8),

                if (r.atCentreAt != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.okSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Tr(
                      'Pick-up complete — continue from the Service button '
                      'on the Requests tab.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ok,
                      ),
                    ),
                  )
                else ...[
                  if (phase != CarServiceStatus.cancelled)
                    PrimaryButton(
                      label: _actionLabel(phase),
                      icon: Icons.arrow_forward,
                      loading: _busy,
                      onPressed: staff.canAdvance ? _advance : null,
                    ),
                  if (!staff.canAdvance && staff.advanceBlockedReason != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              size: 14, color: AppColors.warn),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Tr(
                              staff.advanceBlockedReason!,
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.warn),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _phaseEyebrow(CarServiceStatus s) {
    switch (s) {
      case CarServiceStatus.assigned:
        return 'HEADING TO PICK-UP';
      case CarServiceStatus.pickedUp:
        return 'TAKING CAR TO CENTRE';
      default:
        return 'PICK-UP';
    }
  }
}
