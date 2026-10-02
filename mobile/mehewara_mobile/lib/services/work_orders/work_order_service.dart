import '../../core/network/api_client.dart';
import '../../models/work_order.dart';

class WorkOrderService {
  final ApiClient api;
  WorkOrderService(this.api);
  Future<WorkOrderPage> list({
    int page = 1,
    String status = '',
  }) async => WorkOrderPage.fromJson(
    await api.send(
      '/crew/work-orders?page=$page&pageSize=20&status=${Uri.encodeQueryComponent(status)}',
    ),
  );
  Future<WorkOrder> detail(String id) async =>
      WorkOrder.fromJson(await api.send('/work-orders/$id'));
  Future<WorkOrder> start(String id) async => WorkOrder.fromJson(
    await api.send('/work-orders/$id/start', method: 'POST'),
  );
  Future<WorkOrder> complete(String id, String notes) async =>
      WorkOrder.fromJson(
        await api.send(
          '/work-orders/$id/complete',
          method: 'POST',
          body: {if (notes.trim().isNotEmpty) 'completionNotes': notes.trim()},
        ),
      );
}
