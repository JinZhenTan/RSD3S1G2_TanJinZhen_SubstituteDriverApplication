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

  bool get isBillable =>
      approval == TaskApproval.included || approval == TaskApproval.approved;

  bool get blocksReturn => approval != TaskApproval.declined && !isDone;

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
