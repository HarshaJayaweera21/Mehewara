using Mehewara.API.DTOs.Common;
using Mehewara.API.DTOs.Dispatch;

namespace Mehewara.API.Services.Interfaces;

public interface IDispatchService
{
    Task<PagedResult<RecommendationListItemDto>> GetRecommendationsAsync(RecommendationQueryParams query);
    Task<RecommendationDetailDto?> GetRecommendationByIdAsync(Guid recommendationId);
    Task<RecommendationDetailDto> EditRecommendationAsync(Guid recommendationId, EditRecommendationRequest request, Guid adminUserId);
    Task<ApproveRecommendationResponseDto> ApproveRecommendationAsync(Guid recommendationId, ApproveRecommendationRequest request, Guid adminUserId);
    Task<RejectRecommendationResponseDto> RejectRecommendationAsync(Guid recommendationId, RejectRecommendationRequest request, Guid adminUserId);
    Task<RegenerateRecommendationResponseDto> RegenerateRecommendationAsync(Guid recommendationId, RegenerateRecommendationRequest request, Guid adminUserId);
}
