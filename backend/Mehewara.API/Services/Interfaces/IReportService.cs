using Mehewara.API.DTOs.Common;
using Mehewara.API.DTOs.Reports;
using Microsoft.AspNetCore.Http;

namespace Mehewara.API.Services.Interfaces;

public interface IReportService
{
    Task<ReportResponse> CreateReportAsync(Guid residentId, CreateReportRequest request);
    Task<PagedResult<ReportSummaryResponse>> GetReportsAsync(ReportFilterRequest filter);
    Task<ReportResponse> GetReportByIdAsync(Guid reportId, Guid userId, string userRole);
    Task<PagedResult<ReportSummaryResponse>> GetResidentReportsAsync(Guid residentId, int page, int pageSize, string? status, string? sortBy, string? sortDirection);
    Task<ReportPhotoDto> UploadReportPhotoAsync(IFormFile file);
}
