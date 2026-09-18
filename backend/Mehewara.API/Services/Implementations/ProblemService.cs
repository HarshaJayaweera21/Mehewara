using Mehewara.API.Data;
using Mehewara.API.DTOs.Problems;
using Mehewara.API.Models;
using Mehewara.API.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Mehewara.API.Services.Implementations;

public class ProblemService : IProblemService
{
    private readonly AppDbContext _context;

    public ProblemService(AppDbContext context)
    {
        _context = context;
    }

    public async Task<ProblemResponse> CreateProblemAsync(
        CreateProblemRequest request)
    {
        var problem = new Problem
        {
            ProblemId = Guid.NewGuid(),
            Title = request.Title,
            Description = request.Description,
            Category = request.Category,
            Latitude = request.Latitude,
            Longitude = request.Longitude,
            Address = request.Address,

            Status = "IDENTIFIED",

            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        _context.Problems.Add(problem);

        await _context.SaveChangesAsync();

        return new ProblemResponse
        {
            Id = problem.ProblemId,
            Title = problem.Title,
            Description = problem.Description,
            Category = problem.Category,
            Latitude = problem.Latitude,
            Longitude = problem.Longitude,
            Address = problem.Address,
            Priority = problem.Priority,
            PriorityScore = problem.PriorityScore,
            Status = problem.Status,
            CreatedAt = problem.CreatedAt,
            UpdatedAt = problem.UpdatedAt
        };
    }
}