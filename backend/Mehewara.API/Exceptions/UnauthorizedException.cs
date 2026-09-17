using System.Net;

namespace Mehewara.API.Exceptions;

public class UnauthorizedException : AppException
{
    public UnauthorizedException(string message = "You are not authorized to access this resource.", string errorCode = "UNAUTHORIZED")
        : base(message, HttpStatusCode.Unauthorized, errorCode)
    {
    }
}
