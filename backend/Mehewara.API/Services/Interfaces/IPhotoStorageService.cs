using Microsoft.AspNetCore.Http;

namespace Mehewara.API.Services.Interfaces;

public interface IPhotoStorageService
{
    Task<(string Url, string PublicId)> UploadPhotoAsync(IFormFile file, string folder);
    Task<bool> DeletePhotoAsync(string publicId);
}
