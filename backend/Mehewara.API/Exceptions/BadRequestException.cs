using System.Net;

namespace Mehewara.API.Exceptions;

public class BadRequestException : AppException
{
    public BadRequestException(string message, string errorCode = "BAD_REQUEST", object? details = null)
        : base(message, HttpStatusCode.BadRequest, errorCode, details)
    {
    }
}
