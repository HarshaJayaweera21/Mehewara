using Mehewara.API.Models;

namespace Mehewara.API.Services.Interfaces;

public interface ITokenService
{
    (string Token, DateTime ExpiresAt) GenerateToken(User user);
}
