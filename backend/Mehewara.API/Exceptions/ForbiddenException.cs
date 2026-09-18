using System.Net;

namespace Mehewara.API.Exceptions;

public class ForbiddenException : AppException
{
    public ForbiddenException(string message = "You do not have permission to access this resource.", string errorCode = "FORBIDDEN")
        : base(message, HttpStatusCode.Forbidden, errorCode)
    {
    }
}
