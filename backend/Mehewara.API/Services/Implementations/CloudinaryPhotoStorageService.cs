using CloudinaryDotNet;
using CloudinaryDotNet.Actions;
using Mehewara.API.Common;
using Mehewara.API.Exceptions;
using Mehewara.API.Services.Interfaces;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Options;

namespace Mehewara.API.Services.Implementations;

public class CloudinaryPhotoStorageService : IPhotoStorageService
{
    private readonly Cloudinary _cloudinary;
    private readonly ILogger<CloudinaryPhotoStorageService> _logger;

    public CloudinaryPhotoStorageService(
        IOptions<CloudinarySettings> config,
        ILogger<CloudinaryPhotoStorageService> logger)
    {
        _logger = logger;
        var settings = config.Value;

        if (string.IsNullOrWhiteSpace(settings.CloudName) ||
            string.IsNullOrWhiteSpace(settings.ApiKey) ||
            string.IsNullOrWhiteSpace(settings.ApiSecret))
        {
            _logger.LogWarning("Cloudinary credentials are not configured. Uploads will fail until configured in User Secrets or appsettings.");
        }

        var account = new Account(
            settings.CloudName,
            settings.ApiKey,
            settings.ApiSecret
        );

        _cloudinary = new Cloudinary(account);
        _cloudinary.Api.Secure = true;
    }

    public async Task<(string Url, string PublicId)> UploadPhotoAsync(IFormFile file, string folder)
    {
        if (file == null || file.Length == 0)
        {
            throw new BadRequestException("No image file provided.");
        }

        if (file.Length > 5 * 1024 * 1024)
        {
            throw new BadRequestException("File size exceeds 5MB limit.");
        }

        var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".webp" };
        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (string.IsNullOrEmpty(ext) || !allowedExtensions.Contains(ext))
        {
            throw new BadRequestException("Invalid image format. Allowed formats: JPG, PNG, WEBP.");
        }

        await using var stream = file.OpenReadStream();

        var uploadParams = new ImageUploadParams
        {
            File = new FileDescription(file.FileName, stream),
            Folder = folder,
            Transformation = new Transformation().Width(1200).Height(1200).Crop("limit").Quality("auto")
        };

        var uploadResult = await _cloudinary.UploadAsync(uploadParams);

        if (uploadResult.Error != null)
        {
            _logger.LogError("Cloudinary upload failed: {Message}", uploadResult.Error.Message);
            throw new BadRequestException($"Image upload failed: {uploadResult.Error.Message}");
        }

        var secureUrl = uploadResult.SecureUrl?.ToString() ?? uploadResult.Url?.ToString() ?? string.Empty;
        var publicId = uploadResult.PublicId;

        return (secureUrl, publicId);
    }

    public async Task<bool> DeletePhotoAsync(string publicId)
    {
        if (string.IsNullOrWhiteSpace(publicId))
        {
            return false;
        }

        try
        {
            var deleteParams = new DeletionParams(publicId);
            var result = await _cloudinary.DestroyAsync(deleteParams);
            return result.Result == "ok";
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to delete photo from Cloudinary: {PublicId}", publicId);
            return false;
        }
    }
}
