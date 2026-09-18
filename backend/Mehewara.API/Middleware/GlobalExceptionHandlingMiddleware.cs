using System.Net;
using System.Text.Json;
using Mehewara.API.Exceptions;

namespace Mehewara.API.Middleware;

public class GlobalExceptionHandlingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<GlobalExceptionHandlingMiddleware> _logger;

    public GlobalExceptionHandlingMiddleware(RequestDelegate next, ILogger<GlobalExceptionHandlingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "An unhandled exception occurred during request execution: {Path}", context.Request.Path);
            await HandleExceptionAsync(context, ex);
        }
    }

    private static async Task HandleExceptionAsync(HttpContext context, Exception exception)
    {
        context.Response.ContentType = "application/json";

        HttpStatusCode statusCode;
        string errorCode;
        string message;
        object? details = null;

        if (exception is AppException appEx)
        {
            statusCode = appEx.StatusCode;
            errorCode = appEx.ErrorCode;
            message = appEx.Message;
            details = appEx.Details;
        }
        else
        {
            (statusCode, errorCode, message) = exception switch
            {
                UnauthorizedAccessException unauthorizedEx => (
                    HttpStatusCode.Unauthorized,
                    "UNAUTHORIZED",
                    unauthorizedEx.Message
                ),
                KeyNotFoundException notFoundEx => (
                    HttpStatusCode.NotFound,
                    "NOT_FOUND",
                    notFoundEx.Message
                ),
                InvalidOperationException invalidOpEx when invalidOpEx.Message.Contains("inactive", StringComparison.OrdinalIgnoreCase) => (
                    HttpStatusCode.Forbidden,
                    "USER_NOT_ALLOWED",
                    invalidOpEx.Message
                ),
                InvalidOperationException invalidOpEx => (
                    HttpStatusCode.BadRequest,
                    "INVALID_OPERATION",
                    invalidOpEx.Message
                ),
                ArgumentException argEx => (
                    HttpStatusCode.BadRequest,
                    "VALIDATION_ERROR",
                    argEx.Message
                ),
                _ => (
                    HttpStatusCode.InternalServerError,
                    "INTERNAL_ERROR",
                    "An unexpected server error occurred."
                )
            };
        }

        context.Response.StatusCode = (int)statusCode;

        var traceId = context.TraceIdentifier;

        var errorResponse = new
        {
            error = new
            {
                code = errorCode,
                message = message,
                details = details,
                traceId = traceId
            }
        };

        var options = new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        };

        var json = JsonSerializer.Serialize(errorResponse, options);
        await context.Response.WriteAsync(json);
    }
}
