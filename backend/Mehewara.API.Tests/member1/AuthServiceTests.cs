using Mehewara.API.Common;
using Mehewara.API.Data;
using Mehewara.API.DTOs.Auth;
using Mehewara.API.Exceptions;
using Mehewara.API.Models;
using Mehewara.API.Services.Implementations;
using Mehewara.API.Services.Interfaces;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Xunit;

namespace Mehewara.API.Tests;

public class UnusedPhotoStorageService : IPhotoStorageService
{
    public Task<(string Url, string PublicId)> UploadPhotoAsync(IFormFile file, string folder)
        => throw new InvalidOperationException("Photo storage should not be invoked by these test paths.");

    public Task<bool> DeletePhotoAsync(string publicId)
        => throw new InvalidOperationException("Photo storage should not be invoked by these test paths.");
}

public class AuthServiceTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly AuthService _service;
    private readonly Role _residentRole;

    public AuthServiceTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        _context = new AppDbContext(options);

        _residentRole = new Role { RoleId = Guid.NewGuid(), RoleCode = "RESIDENT", RoleName = "Resident", IsActive = true };
        _context.Roles.Add(_residentRole);
        _context.SaveChanges();

        var jwtSettings = Options.Create(new JwtSettings
        {
            Key = "unit-test-signing-key-must-be-at-least-32-bytes-long",
            Issuer = "mehewara-test",
            Audience = "mehewara-test",
            ExpiryHours = 24,
        });
        var tokenService = new TokenService(jwtSettings);
        var configuration = new ConfigurationBuilder().Build();

        _service = new AuthService(
            _context,
            tokenService,
            configuration,
            new UnusedPhotoStorageService(),
            NullLogger<AuthService>.Instance);
    }

    public void Dispose() => _context.Dispose();

    private User SeedUser(string email, string password, bool isActive = true, string? firstName = "Kamal", string? lastName = "Perera")
    {
        var user = new User
        {
            UserId = Guid.NewGuid(),
            RoleId = _residentRole.RoleId,
            Role = _residentRole,
            FirstName = firstName ?? string.Empty,
            LastName = lastName ?? string.Empty,
            Email = email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(password),
            IsActive = isActive,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
        };
        _context.Users.Add(user);
        _context.SaveChanges();
        return user;
    }

    [Fact]
    public async Task LoginAsync_WithCorrectCredentials_ReturnsAccessTokenAndUser()
    {
        SeedUser("kamal@example.com", "Resident@123");

        var result = await _service.LoginAsync(new LoginRequest { Email = "Kamal@Example.com", Password = "Resident@123" });

        Assert.False(string.IsNullOrWhiteSpace(result.AccessToken));
        Assert.Equal("kamal@example.com", result.User.Email);
        Assert.Equal("RESIDENT", result.User.Role);
    }

    [Fact]
    public async Task LoginAsync_WithWrongPassword_ThrowsInvalidCredentialsException()
    {
        SeedUser("kamal@example.com", "Resident@123");

        await Assert.ThrowsAsync<InvalidCredentialsException>(() =>
            _service.LoginAsync(new LoginRequest { Email = "kamal@example.com", Password = "WrongPassword" }));
    }

    [Fact]
    public async Task LoginAsync_WithUnknownEmail_ThrowsInvalidCredentialsException()
    {
        await Assert.ThrowsAsync<InvalidCredentialsException>(() =>
            _service.LoginAsync(new LoginRequest { Email = "nobody@example.com", Password = "whatever" }));
    }

    [Fact]
    public async Task LoginAsync_WithInactiveAccount_ThrowsUserNotAllowedException()
    {
        SeedUser("kamal@example.com", "Resident@123", isActive: false);

        await Assert.ThrowsAsync<UserNotAllowedException>(() =>
            _service.LoginAsync(new LoginRequest { Email = "kamal@example.com", Password = "Resident@123" }));
    }

    [Fact]
    public async Task RegisterAsync_WithNewEmail_CreatesResidentAndReturnsToken()
    {
        var result = await _service.RegisterAsync(new RegisterRequest
        {
            FirstName = " Kasun ",
            LastName = " Silva ",
            Email = "Kasun@Example.com",
            Password = "Secret@123",
        });

        Assert.Equal("kasun@example.com", result.User.Email);
        Assert.Equal("Kasun Silva", result.User.Name);
        Assert.Equal("RESIDENT", result.User.Role);
        Assert.False(string.IsNullOrWhiteSpace(result.AccessToken));
    }

    [Fact]
    public async Task RegisterAsync_WithExistingEmail_ThrowsConflictException()
    {
        SeedUser("kamal@example.com", "Resident@123");

        await Assert.ThrowsAsync<ConflictException>(() => _service.RegisterAsync(new RegisterRequest
        {
            FirstName = "Kamal",
            LastName = "Perera",
            Email = "kamal@example.com",
            Password = "AnotherPass1",
        }));
    }

    [Fact]
    public async Task UpdateProfileAsync_TrimsNamesAndUpdatesOnlyProvidedFields()
    {
        var user = SeedUser("kamal@example.com", "Resident@123", lastName: "Original");

        var updated = await _service.UpdateProfileAsync(user.UserId, new UpdateProfileRequest
        {
            FirstName = "  Updated  ",
            PhoneNumber = "0771234567",
        });

        Assert.Equal("Updated", updated.FirstName);
        Assert.Equal("Original", updated.LastName);
        Assert.Equal("0771234567", updated.PhoneNumber);
    }

    [Fact]
    public async Task UpdateProfileAsync_WithUnknownUserId_ThrowsNotFoundException()
    {
        await Assert.ThrowsAsync<NotFoundException>(() =>
            _service.UpdateProfileAsync(Guid.NewGuid(), new UpdateProfileRequest { FirstName = "X" }));
    }

    [Fact]
    public async Task GetCurrentUserAsync_WithKnownUserId_ReturnsMappedUser()
    {
        var user = SeedUser("kamal@example.com", "Resident@123");

        var result = await _service.GetCurrentUserAsync(user.UserId);

        Assert.Equal(user.Email, result.Email);
        Assert.Equal("Kamal Perera", result.Name);
    }

    [Fact]
    public async Task GetCurrentUserAsync_WithUnknownUserId_ThrowsNotFoundException()
    {
        await Assert.ThrowsAsync<NotFoundException>(() => _service.GetCurrentUserAsync(Guid.NewGuid()));
    }

    [Fact]
    public async Task RemoveProfilePhotoAsync_ClearsProfileImageUrlWithoutCallingPhotoStorage()
    {
        var user = SeedUser("kamal@example.com", "Resident@123");
        user.ProfileImageUrl = "https://cdn.example.com/old.jpg";
        await _context.SaveChangesAsync();

        var result = await _service.RemoveProfilePhotoAsync(user.UserId);

        Assert.Null(result.ProfileImageUrl);
    }
}
