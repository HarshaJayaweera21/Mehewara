using System.Net;

namespace Mehewara.API.Exceptions;

public class ValidationException : AppException
{
    public ValidationException(string message = "One or more fields are invalid.", object? details = null)
        : base(message, HttpStatusCode.BadRequest, "VALIDATION_ERROR", details)
    {
    }
}
