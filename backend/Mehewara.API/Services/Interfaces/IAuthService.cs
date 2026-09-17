using Mehewara.API.DTOs.Auth;

namespace Mehewara.API.Services.Interfaces;

public interface IAuthService
{
    Task<LoginResponse> LoginAsync(LoginRequest request);
    Task<LoginResponse> LoginWithGoogleAsync(GoogleLoginRequest request);
    Task<UserDto> GetCurrentUserAsync(Guid userId);
}
