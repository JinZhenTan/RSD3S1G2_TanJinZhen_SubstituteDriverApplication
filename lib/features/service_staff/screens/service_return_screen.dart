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

class ServiceReturnScreen extends StatefulWidget {
  const ServiceReturnScreen({super.key});

  @override
  State<ServiceReturnScreen> createState() => _ServiceReturnScreenState();
}

class _ServiceReturnScreenState extends State<ServiceReturnScreen> {
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
        phase: ServicePhotoPhase.ret,
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

  @override
  Widget build(BuildContext context) {
    final staff = context.watch<ServiceStaffProvider>();
    final r = staff.active;

    if (r == null) {
      return const Scaffold(body: Center(child: Tr('No job selected')));
    }

    final returned = r.status == CarServiceStatus.returned;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          ScreenHeader(
            eyebrow: returned ? 'CAR RETURNED' : 'ON THE WAY BACK',
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
                _ReturnDestinationCard(request: r),
                const SizedBox(height: 16),

                sectionTitle('RETURN PHOTOS'),
                const SizedBox(height: 8),
                PhotoStrip(
                  label: 'Return',
                  photos: staff.photos
                      .where((p) => p.phase == ServicePhotoPhase.ret)
                      .toList(),
                  onAdd: returned ? null : _addPhoto,
                ),
                const SizedBox(height: 16),

                sectionTitle('STATUS'),
                const SizedBox(height: 8),
                StepRow(
                  label: 'On the way back',
                  done: returned,
                  active: !returned,
                ),
                StepRow(
                  label: 'Returned',
                  done: returned,
                  active: false,
                ),
                const SizedBox(height: 8),

                if (!returned) ...[
                  PrimaryButton(
                    label: 'Mark returned',
                    icon: Icons.arrow_forward,
                    loading: _busy,
                    onPressed: staff.canAdvance
                        ? () => _staff.advanceStatus()
                        : null,
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
                if (returned)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: r.paymentStatus == 'paid'
                          ? AppColors.okSoft
                          : AppColors.blue50,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Tr(
                      r.paymentStatus == 'paid'
                          ? 'Owner has paid RM ${(r.finalCost ?? staff.billableTotal).toStringAsFixed(2)} — job complete.'
                          : 'Car returned. Final bill RM ${(r.finalCost ?? staff.billableTotal).toStringAsFixed(2)} — waiting on the owner to pay.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: r.paymentStatus == 'paid'
                            ? AppColors.ok
                            : AppColors.blue700,
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
}

class _ReturnDestinationCard extends StatelessWidget {
  const _ReturnDestinationCard({required this.request});

  final CarServiceRequest request;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppStyles.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_return_outlined,
                  size: 16, color: AppColors.blue600),
              const SizedBox(width: 8),
              Tr('Returning to',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  )),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            request.pickupAddress,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
