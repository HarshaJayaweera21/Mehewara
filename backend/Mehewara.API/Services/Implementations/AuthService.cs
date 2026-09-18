using Google.Apis.Auth;
using Mehewara.API.Data;
using Mehewara.API.DTOs.Auth;
using Mehewara.API.Exceptions;
using Mehewara.API.Models;
using Mehewara.API.Services.Interfaces;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;

namespace Mehewara.API.Services.Implementations;

public class AuthService : IAuthService
{
    private readonly AppDbContext _context;
    private readonly ITokenService _tokenService;
    private readonly IConfiguration _configuration;
    private readonly IPhotoStorageService _photoStorageService;
    private readonly ILogger<AuthService> _logger;

    public AuthService(
        AppDbContext context,
        ITokenService tokenService,
        IConfiguration configuration,
        IPhotoStorageService photoStorageService,
        ILogger<AuthService> logger)
    {
        _context = context;
        _tokenService = tokenService;
        _configuration = configuration;
        _photoStorageService = photoStorageService;
        _logger = logger;
    }

    public async Task<LoginResponse> LoginAsync(LoginRequest request)
    {
        var normalizedEmail = request.Email.Trim().ToLowerInvariant();

        var user = await _context.Users
            .Include(u => u.Role)
            .FirstOrDefaultAsync(u => u.Email.ToLower() == normalizedEmail);

        if (user == null || !BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash))
        {
            throw new InvalidCredentialsException("Invalid email or password.");
        }

        if (!user.IsActive)
        {
            throw new UserNotAllowedException("User account is inactive.");
        }

        var (token, expiresAt) = _tokenService.GenerateToken(user);

        return new LoginResponse
        {
            AccessToken = token,
            ExpiresAt = expiresAt,
            User = MapToUserDto(user)
        };
    }

    public async Task<LoginResponse> LoginWithGoogleAsync(GoogleLoginRequest request)
    {
        GoogleJsonWebSignature.Payload payload;

        try
        {
            var googleClientId = _configuration["Google:ClientId"];
            var validationSettings = new GoogleJsonWebSignature.ValidationSettings();

            if (!string.IsNullOrWhiteSpace(googleClientId))
            {
                validationSettings.Audience = new[] { googleClientId };
            }

            payload = await GoogleJsonWebSignature.ValidateAsync(request.IdToken, validationSettings);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Google token validation failed");
            throw new InvalidCredentialsException("Google authentication token is invalid or expired.");
        }

        if (string.IsNullOrEmpty(payload.Email))
        {
            throw new InvalidCredentialsException("Google account has no associated email.");
        }

        var normalizedEmail = payload.Email.Trim().ToLowerInvariant();

        var user = await _context.Users
            .Include(u => u.Role)
            .FirstOrDefaultAsync(u => u.Email.ToLower() == normalizedEmail);

        if (user == null)
        {
            var residentRole = await _context.Roles
                .FirstOrDefaultAsync(r => r.RoleCode == "RESIDENT");

            if (residentRole == null)
            {
                throw new InvalidOperationException("Default RESIDENT role was not found in database.");
            }

            var firstName = !string.IsNullOrWhiteSpace(payload.GivenName) ? payload.GivenName : payload.Name ?? "Resident";
            var lastName = !string.IsNullOrWhiteSpace(payload.FamilyName) ? payload.FamilyName : string.Empty;

            user = new User
            {
                UserId = Guid.NewGuid(),
                RoleId = residentRole.RoleId,
                FirstName = firstName,
                LastName = lastName,
                Email = normalizedEmail,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(Guid.NewGuid().ToString("N")),
                ProfileImageUrl = payload.Picture,
                IsActive = true,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                Role = residentRole
            };

            _context.Users.Add(user);
            await _context.SaveChangesAsync();

            _logger.LogInformation("New user auto-provisioned via Google OAuth: {Email}", normalizedEmail);
        }
        else
        {
            if (!user.IsActive)
            {
                throw new UserNotAllowedException("User account is inactive.");
            }

            // Sync profile picture from Google if missing
            if (string.IsNullOrEmpty(user.ProfileImageUrl) && !string.IsNullOrEmpty(payload.Picture))
            {
                user.ProfileImageUrl = payload.Picture;
                await _context.SaveChangesAsync();
            }
        }

        var (token, expiresAt) = _tokenService.GenerateToken(user);

        return new LoginResponse
        {
            AccessToken = token,
            ExpiresAt = expiresAt,
            User = MapToUserDto(user)
        };
    }

    public async Task<LoginResponse> RegisterAsync(RegisterRequest request)
    {
        var normalizedEmail = request.Email.Trim().ToLowerInvariant();

        var emailExists = await _context.Users
            .AnyAsync(u => u.Email.ToLower() == normalizedEmail);

        if (emailExists)
        {
            throw new ConflictException("An account with this email address already exists.", "EMAIL_ALREADY_EXISTS");
        }

        var residentRole = await _context.Roles
            .FirstOrDefaultAsync(r => r.RoleCode == "RESIDENT");

        if (residentRole == null)
        {
            throw new InvalidOperationException("Default RESIDENT role was not found.");
        }

        var user = new User
        {
            UserId = Guid.NewGuid(),
            RoleId = residentRole.RoleId,
            FirstName = request.FirstName.Trim(),
            LastName = request.LastName.Trim(),
            Email = normalizedEmail,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password),
            PhoneNumber = string.IsNullOrWhiteSpace(request.PhoneNumber) ? null : request.PhoneNumber.Trim(),
            ProfileImageUrl = null, // User uploads photo via Cloudinary later
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
            Role = residentRole
        };

        _context.Users.Add(user);
        await _context.SaveChangesAsync();

        _logger.LogInformation("New resident registered: {Email}", normalizedEmail);

        var (token, expiresAt) = _tokenService.GenerateToken(user);

        return new LoginResponse
        {
            AccessToken = token,
            ExpiresAt = expiresAt,
            User = MapToUserDto(user)
        };
    }

    public async Task<UserDto> UpdateProfileAsync(Guid userId, UpdateProfileRequest request)
    {
        var user = await _context.Users
            .Include(u => u.Role)
            .FirstOrDefaultAsync(u => u.UserId == userId);

        if (user == null)
        {
            throw new NotFoundException("User not found.");
        }

        if (!string.IsNullOrWhiteSpace(request.FirstName))
        {
            user.FirstName = request.FirstName.Trim();
        }

        if (!string.IsNullOrWhiteSpace(request.LastName))
        {
            user.LastName = request.LastName.Trim();
        }

        if (request.PhoneNumber != null)
        {
            user.PhoneNumber = string.IsNullOrWhiteSpace(request.PhoneNumber) ? null : request.PhoneNumber.Trim();
        }

        user.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        return MapToUserDto(user);
    }

    public async Task<UserDto> UploadProfilePhotoAsync(Guid userId, IFormFile file)
    {
        var user = await _context.Users
            .Include(u => u.Role)
            .FirstOrDefaultAsync(u => u.UserId == userId);

        if (user == null)
        {
            throw new NotFoundException("User not found.");
        }

        var (photoUrl, _) = await _photoStorageService.UploadPhotoAsync(file, "mehewara/profiles");

        user.ProfileImageUrl = photoUrl;
        user.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        _logger.LogInformation("Profile photo uploaded to Cloudinary for user: {UserId}", userId);

        return MapToUserDto(user);
    }

    public async Task<UserDto> RemoveProfilePhotoAsync(Guid userId)
    {
        var user = await _context.Users
            .Include(u => u.Role)
            .FirstOrDefaultAsync(u => u.UserId == userId);

        if (user == null)
        {
            throw new NotFoundException("User not found.");
        }

        user.ProfileImageUrl = null;
        user.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        return MapToUserDto(user);
    }

    public async Task<UserDto> GetCurrentUserAsync(Guid userId)
    {
        var user = await _context.Users
            .Include(u => u.Role)
            .FirstOrDefaultAsync(u => u.UserId == userId);

        if (user == null)
        {
            throw new NotFoundException("User not found.");
        }

        return MapToUserDto(user);
    }

    private static UserDto MapToUserDto(User user)
    {
        return new UserDto
        {
            Id = user.UserId,
            FirstName = user.FirstName,
            LastName = user.LastName,
            Name = $"{user.FirstName} {user.LastName}".Trim(),
            Email = user.Email,
            Role = user.Role?.RoleCode ?? "RESIDENT",
            PhoneNumber = user.PhoneNumber,
            ProfileImageUrl = user.ProfileImageUrl
        };
    }
}
