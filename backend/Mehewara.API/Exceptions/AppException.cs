using System.Net;

namespace Mehewara.API.Exceptions;

public abstract class AppException : Exception
{
    public HttpStatusCode StatusCode { get; }
    public string ErrorCode { get; }
    public object? Details { get; }

    protected AppException(string message, HttpStatusCode statusCode, string errorCode, object? details = null)
        : base(message)
    {
        StatusCode = statusCode;
        ErrorCode = errorCode;
        Details = details;
    }
}
