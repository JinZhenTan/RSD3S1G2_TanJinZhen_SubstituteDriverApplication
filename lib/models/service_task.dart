// Model class for a row of the Supabase 'service_tasks' table (Module 3).
//
// One line item on a car-service job. The staff ticks each one done as they
// work through it, and the owner sees the same checklist live.
//
//   included  - part of the booked service (pre-seeded from the service type)
//   pending   - extra work the staff found; waiting on the owner's decision
//   approved  - owner said go ahead (counts toward the final cost)
//   declined  - owner said no (skipped, not billed)
enum TaskApproval { included, pending, approved, declined }

TaskApproval taskApprovalFromName(String? name) {
  for (final a in TaskApproval.values) {
    if (a.name == name) return a;
  }
  return TaskApproval.included;
}

class ServiceTask {
  final String id;
  final String serviceRequestId;
  final String title;
  final String? detail;
  final double price;
  final bool isDone;
  final DateTime? doneAt;
  final bool isExtra;
  final TaskApproval approval;
  final DateTime createdAt;

  ServiceTask({
    required this.id,
    required this.serviceRequestId,
    required this.title,
    this.detail,
    required this.price,
    required this.isDone,
    this.doneAt,
    required this.isExtra,
    required this.approval,
    required this.createdAt,
  });

  // Whether this task's price is part of the bill.
  bool get isBillable =>
      approval == TaskApproval.included || approval == TaskApproval.approved;

  // Whether this task still needs the staff to tick it before the car can be
  // marked "Returned" (a declined extra is skipped).
  bool get blocksReturn => approval != TaskApproval.declined && !isDone;

  // clearDoneAt handles unticking a task, where doneAt needs to become null
  // rather than just "unchanged" - a plain `doneAt ?? this.doneAt` can't
  // express clearing a field back to null.
  ServiceTask copyWith({
    bool? isDone,
    DateTime? doneAt,
    bool clearDoneAt = false,
    TaskApproval? approval,
  }) {
    return ServiceTask(
      id: id,
      serviceRequestId: serviceRequestId,
      title: title,
      detail: detail,
      price: price,
      isDone: isDone ?? this.isDone,
      doneAt: clearDoneAt ? null : (doneAt ?? this.doneAt),
      isExtra: isExtra,
      approval: approval ?? this.approval,
      createdAt: createdAt,
    );
  }

  factory ServiceTask.fromJson(Map<String, dynamic> json) {
    return ServiceTask(
      id: json['id'].toString(),
      serviceRequestId: json['service_request_id'].toString(),
      title: (json['title'] ?? '') as String,
      detail: json['detail'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      isDone: (json['is_done'] ?? false) as bool,
      doneAt: DateTime.tryParse(json['done_at']?.toString() ?? ''),
      isExtra: (json['is_extra'] ?? false) as bool,
      approval: taskApprovalFromName(json['approval'] as String?),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
