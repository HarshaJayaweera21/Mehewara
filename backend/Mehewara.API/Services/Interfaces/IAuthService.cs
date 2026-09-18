using Mehewara.API.DTOs.Auth;
using Microsoft.AspNetCore.Http;

namespace Mehewara.API.Services.Interfaces;

public interface IAuthService
{
    Task<LoginResponse> LoginAsync(LoginRequest request);
    Task<LoginResponse> LoginWithGoogleAsync(GoogleLoginRequest request);
    Task<LoginResponse> RegisterAsync(RegisterRequest request);
    Task<UserDto> UpdateProfileAsync(Guid userId, UpdateProfileRequest request);
    Task<UserDto> UploadProfilePhotoAsync(Guid userId, IFormFile file);
    Task<UserDto> RemoveProfilePhotoAsync(Guid userId);
    Task<UserDto> GetCurrentUserAsync(Guid userId);
}
