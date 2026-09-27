using Mehewara.API.DTOs.Common;
using Mehewara.API.DTOs.WorkOrders;

namespace Mehewara.API.Services.Interfaces;

public interface IWorkOrderService
{
    Task<PagedResult<WorkOrderDto>> GetAdminOrdersAsync(WorkOrderQuery query);
    Task<PagedResult<WorkOrderDto>> GetCrewOrdersAsync(WorkOrderQuery query, Guid userId);
    Task<WorkOrderDto> GetOrderAsync(Guid id, Guid userId, bool isAdmin);
    Task<WorkOrderDto> StartAsync(Guid id, Guid userId);
    Task<WorkOrderDto> CompleteAsync(Guid id, Guid userId, CompleteWorkOrderRequest request);
}
