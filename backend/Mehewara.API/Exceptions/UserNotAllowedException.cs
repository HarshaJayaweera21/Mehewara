using System.Net;

namespace Mehewara.API.Exceptions;

public class UserNotAllowedException : AppException
{
    public UserNotAllowedException(string message = "User account is inactive or not permitted.")
        : base(message, HttpStatusCode.Forbidden, "USER_NOT_ALLOWED")
    {
    }
}
