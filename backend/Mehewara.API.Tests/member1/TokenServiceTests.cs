using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Mehewara.API.Common;
using Mehewara.API.Models;
using Mehewara.API.Services.Implementations;
using Microsoft.Extensions.Options;
using Xunit;

namespace Mehewara.API.Tests;

public class TokenServiceTests
{
    private static TokenService BuildService(int expiryHours = 24)
    {
        var settings = new JwtSettings
        {
            Key = "unit-test-signing-key-must-be-at-least-32-bytes-long",
            Issuer = "mehewara-test-issuer",
            Audience = "mehewara-test-audience",
            ExpiryHours = expiryHours,
        };
        return new TokenService(Options.Create(settings));
    }

    private static User BuildUser(string role = "RESIDENT") => new()
    {
        UserId = Guid.NewGuid(),
        FirstName = "Kamal",
        LastName = "Perera",
        Email = "kamal@example.com",
        Role = new Role { RoleId = Guid.NewGuid(), RoleCode = role, RoleName = role },
    };

    [Fact]
    public void GenerateToken_ProducesTokenExpiringAtConfiguredHoursFromNow()
    {
        var service = BuildService(2);
        var before = DateTime.UtcNow;

        var (_, expiresAt) = service.GenerateToken(BuildUser());

        Assert.InRange(expiresAt, before.AddHours(2).AddSeconds(-5), before.AddHours(2).AddSeconds(5));
    }

    [Fact]
    public void GenerateToken_EmbedsUserIdEmailAndRoleClaims()
    {
        var service = BuildService();
        var user = BuildUser("ADMIN");

        var (token, _) = service.GenerateToken(user);

        var jwt = new JwtSecurityTokenHandler().ReadJwtToken(token);
        Assert.Equal(user.UserId.ToString(), jwt.Claims.First(c => c.Type == JwtRegisteredClaimNames.Sub).Value);
        Assert.Equal(user.Email, jwt.Claims.First(c => c.Type == JwtRegisteredClaimNames.Email).Value);
        // JwtSecurityTokenHandler maps ClaimTypes.Role/Name to their short JWT names ("role"/"unique_name") on write.
        Assert.Equal("ADMIN", jwt.Claims.First(c => c.Type == "role").Value);
        Assert.Equal("Kamal Perera", jwt.Claims.First(c => c.Type == "unique_name").Value);
    }

    [Fact]
    public void GenerateToken_DefaultsRoleToResidentWhenRoleNavigationIsMissing()
    {
        var service = BuildService();
        var user = BuildUser();
        user.Role = null!;

        var (token, _) = service.GenerateToken(user);

        var jwt = new JwtSecurityTokenHandler().ReadJwtToken(token);
        Assert.Equal("RESIDENT", jwt.Claims.First(c => c.Type == "role").Value);
    }

    [Fact]
    public void GenerateToken_SetsConfiguredIssuerAndAudience()
    {
        var service = BuildService();

        var (token, _) = service.GenerateToken(BuildUser());

        var jwt = new JwtSecurityTokenHandler().ReadJwtToken(token);
        Assert.Equal("mehewara-test-issuer", jwt.Issuer);
        Assert.Equal("mehewara-test-audience", jwt.Audiences.First());
    }

    [Fact]
    public void GenerateToken_ProducesADifferentJtiOnEachCall()
    {
        var service = BuildService();
        var user = BuildUser();

        var (tokenA, _) = service.GenerateToken(user);
        var (tokenB, _) = service.GenerateToken(user);

        var handler = new JwtSecurityTokenHandler();
        var jtiA = handler.ReadJwtToken(tokenA).Claims.First(c => c.Type == JwtRegisteredClaimNames.Jti).Value;
        var jtiB = handler.ReadJwtToken(tokenB).Claims.First(c => c.Type == JwtRegisteredClaimNames.Jti).Value;

        Assert.NotEqual(jtiA, jtiB);
    }
}
