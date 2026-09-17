using System.Net;

namespace Mehewara.API.Exceptions;

public class ConflictException : AppException
{
    public ConflictException(string message = "A conflict occurred with the current state of the resource.", string errorCode = "CONFLICT")
        : base(message, HttpStatusCode.Conflict, errorCode)
    {
    }
}
