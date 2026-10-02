using System.Security.Cryptography;
using System.Text;
using Mehewara.API.DTOs.Dispatch;
using Mehewara.API.Services.Implementations;
using Microsoft.AspNetCore.Mvc;

namespace Mehewara.API.Controllers;

[ApiController]
[Route("internal/ai")]
public class AiValidationContextController(AiReviewService review, IConfiguration config) : ControllerBase
{
    [HttpPost("validation-context")]
    public async Task<IActionResult> Context([FromBody] ValidationContextRequest request)
    {
        var expected = config["AiService:InternalApiKey"] ?? "";
        var received = Request.Headers["X-Internal-Api-Key"].ToString();
        if (expected.Length == 0 || !CryptographicOperations.FixedTimeEquals(
            SHA256.HashData(Encoding.UTF8.GetBytes(expected)), SHA256.HashData(Encoding.UTF8.GetBytes(received))))
            return Unauthorized();
        return Ok(await review.GetEvidenceAsync(request));
    }
}
