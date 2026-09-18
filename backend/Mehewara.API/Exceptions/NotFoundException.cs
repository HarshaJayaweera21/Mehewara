using System.Net;

namespace Mehewara.API.Exceptions;

public class NotFoundException : AppException
{
    public NotFoundException(string message = "The requested resource was not found.", string errorCode = "NOT_FOUND")
        : base(message, HttpStatusCode.NotFound, errorCode)
    {
    }
}
