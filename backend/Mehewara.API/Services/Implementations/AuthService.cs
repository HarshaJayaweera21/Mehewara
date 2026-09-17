using Google.Apis.Auth;
using Mehewara.API.Data;
using Mehewara.API.DTOs.Auth;
using Mehewara.API.Exceptions;
using Mehewara.API.Models;
using Mehewara.API.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Mehewara.API.Services.Implementations;

public class AuthService : IAuthService
{
    private readonly AppDbContext _context;
    private readonly ITokenService _tokenService;
    private readonly IConfiguration _configuration;
    private readonly ILogger<AuthService> _logger;

    public AuthService(
        AppDbContext context,
        ITokenService tokenService,
        IConfiguration configuration,
        ILogger<AuthService> logger)
    {
        _context = context;
        _tokenService = tokenService;
        _configuration = configuration;
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
            User = new UserDto
            {
                Id = user.UserId,
                Name = $"{user.FirstName} {user.LastName}".Trim(),
                Email = user.Email,
                Role = user.Role?.RoleCode ?? "RESIDENT"
            }
        };
    }

    public async Task<LoginResponse> LoginWithGoogleAsync(GoogleLoginRequest request)
    {
        GoogleJsonWebSignature.Payload payload;

        try
        {
            var validationSettings = new GoogleJsonWebSignature.ValidationSettings();
            var googleClientId = _configuration["Google:ClientId"];

            if (!string.IsNullOrWhiteSpace(googleClientId) && !googleClientId.Contains("YOUR_GOOGLE_CLIENT_ID"))
            {
                validationSettings.Audience = new[] { googleClientId };
            }

            payload = await GoogleJsonWebSignature.ValidateAsync(request.IdToken, validationSettings);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to validate Google ID Token.");
            throw new InvalidCredentialsException("Invalid Google token.");
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
                throw new InvalidOperationException("Default RESIDENT role was not found.");
            }

            var firstName = !string.IsNullOrWhiteSpace(payload.GivenName)
                ? payload.GivenName
                : (payload.Name?.Split(' ').FirstOrDefault() ?? "Citizen");

            var lastName = !string.IsNullOrWhiteSpace(payload.FamilyName)
                ? payload.FamilyName
                : (payload.Name?.Split(' ').Skip(1).FirstOrDefault() ?? "");

            user = new User
            {
                UserId = Guid.NewGuid(),
                RoleId = residentRole.RoleId,
                FirstName = firstName,
                LastName = lastName,
                Email = normalizedEmail,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(Guid.NewGuid().ToString()),
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
        }

        var (token, expiresAt) = _tokenService.GenerateToken(user);

        return new LoginResponse
        {
            AccessToken = token,
            ExpiresAt = expiresAt,
            User = new UserDto
            {
                Id = user.UserId,
                Name = $"{user.FirstName} {user.LastName}".Trim(),
                Email = user.Email,
                Role = user.Role?.RoleCode ?? "RESIDENT"
            }
        };
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

        return new UserDto
        {
            Id = user.UserId,
            Name = $"{user.FirstName} {user.LastName}".Trim(),
            Email = user.Email,
            Role = user.Role?.RoleCode ?? "RESIDENT"
        };
    }
}
