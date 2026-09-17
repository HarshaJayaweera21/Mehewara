using System.Net;

namespace Mehewara.API.Exceptions;

public class InvalidCredentialsException : AppException
{
    public InvalidCredentialsException(string message = "Invalid email or password.")
        : base(message, HttpStatusCode.Unauthorized, "INVALID_CREDENTIALS")
    {
    }
}
