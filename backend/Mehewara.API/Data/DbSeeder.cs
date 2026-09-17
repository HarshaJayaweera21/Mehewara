using Mehewara.API.Models;
using Microsoft.EntityFrameworkCore;

namespace Mehewara.API.Data;

public static class DbSeeder
{
    public static async Task SeedAsync(AppDbContext context, ILogger logger)
    {
        try
        {
            logger.LogInformation("Checking database tables and seeding initial data...");

            // 1. Seed Roles
            var rolesToSeed = new List<Role>
            {
                new()
                {
                    RoleId = Guid.Parse("11111111-1111-1111-1111-111111111111"),
                    RoleName = "Resident",
                    RoleCode = "RESIDENT",
                    Description = "Municipal resident who submits and tracks reports",
                    IsActive = true
                },
                new()
                {
                    RoleId = Guid.Parse("22222222-2222-2222-2222-222222222222"),
                    RoleName = "Administrator",
                    RoleCode = "ADMIN",
                    Description = "Coordinator/administrator who reviews AI recommendations and manages workflows",
                    IsActive = true
                },
                new()
                {
                    RoleId = Guid.Parse("33333333-3333-3333-3333-333333333333"),
                    RoleName = "Drainage Crew Leader",
                    RoleCode = "CREW_LEADER_DRAINAGE",
                    Description = "Leader of a drainage work crew",
                    IsActive = true
                },
                new()
                {
                    RoleId = Guid.Parse("44444444-4444-4444-4444-444444444444"),
                    RoleName = "Waste Crew Leader",
                    RoleCode = "CREW_LEADER_WASTE",
                    Description = "Leader of a waste management work crew",
                    IsActive = true
                },
                new()
                {
                    RoleId = Guid.Parse("55555555-5555-5555-5555-555555555555"),
                    RoleName = "Road Crew Leader",
                    RoleCode = "CREW_LEADER_ROAD",
                    Description = "Leader of a road maintenance work crew",
                    IsActive = true
                },
                new()
                {
                    RoleId = Guid.Parse("66666666-6666-6666-6666-666666666666"),
                    RoleName = "Electrical Crew Leader",
                    RoleCode = "CREW_LEADER_ELECTRICAL",
                    Description = "Leader of an electrical work crew",
                    IsActive = true
                },
                new()
                {
                    RoleId = Guid.Parse("77777777-7777-7777-7777-777777777777"),
                    RoleName = "Environment Crew Leader",
                    RoleCode = "CREW_LEADER_ENVIRONMENT",
                    Description = "Leader of an environmental and public spaces crew",
                    IsActive = true
                }
            };

            foreach (var role in rolesToSeed)
            {
                if (!await context.Roles.AnyAsync(r => r.RoleCode == role.RoleCode))
                {
                    context.Roles.Add(role);
                }
            }

            await context.SaveChangesAsync();

            var adminRole = await context.Roles.FirstAsync(r => r.RoleCode == "ADMIN");
            var residentRole = await context.Roles.FirstAsync(r => r.RoleCode == "RESIDENT");
            var drainageRole = await context.Roles.FirstAsync(r => r.RoleCode == "CREW_LEADER_DRAINAGE");
            var roadRole = await context.Roles.FirstAsync(r => r.RoleCode == "CREW_LEADER_ROAD");

            // 2. Seed Default Test Users
            var usersToSeed = new List<User>
            {
                new()
                {
                    UserId = Guid.Parse("a0000000-0000-0000-0000-000000000001"),
                    RoleId = adminRole.RoleId,
                    FirstName = "Municipal",
                    LastName = "Coordinator",
                    Email = "admin@mehewara.gov.lk",
                    PasswordHash = BCrypt.Net.BCrypt.HashPassword("Admin@123"),
                    PhoneNumber = "+94112345670",
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                },
                new()
                {
                    UserId = Guid.Parse("a0000000-0000-0000-0000-000000000002"),
                    RoleId = residentRole.RoleId,
                    FirstName = "Kamal",
                    LastName = "Perera",
                    Email = "resident@example.com",
                    PasswordHash = BCrypt.Net.BCrypt.HashPassword("Resident@123"),
                    PhoneNumber = "+94771234567",
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                },
                new()
                {
                    UserId = Guid.Parse("a0000000-0000-0000-0000-000000000003"),
                    RoleId = drainageRole.RoleId,
                    FirstName = "Sunil",
                    LastName = "Shanmugaratnam",
                    Email = "crew.drainage@mehewara.gov.lk",
                    PasswordHash = BCrypt.Net.BCrypt.HashPassword("Crew@123"),
                    PhoneNumber = "+94772345678",
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                },
                new()
                {
                    UserId = Guid.Parse("a0000000-0000-0000-0000-000000000004"),
                    RoleId = roadRole.RoleId,
                    FirstName = "Nimal",
                    LastName = "Silva",
                    Email = "crew.road@mehewara.gov.lk",
                    PasswordHash = BCrypt.Net.BCrypt.HashPassword("Crew@123"),
                    PhoneNumber = "+94773456789",
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                }
            };

            foreach (var user in usersToSeed)
            {
                if (!await context.Users.AnyAsync(u => u.Email == user.Email))
                {
                    context.Users.Add(user);
                }
            }

            await context.SaveChangesAsync();

            // 3. Seed Crews if none exist
            if (!await context.Crews.AnyAsync())
            {
                var drainageUser = await context.Users.FirstAsync(u => u.Email == "crew.drainage@mehewara.gov.lk");
                var roadUser = await context.Users.FirstAsync(u => u.Email == "crew.road@mehewara.gov.lk");

                context.Crews.AddRange(
                    new Crew
                    {
                        CrewId = Guid.Parse("c0000000-0000-0000-0000-000000000001"),
                        CrewName = "Drainage Rapid Response Unit Alpha",
                        CrewType = "DRAINAGE",
                        CrewLeaderUserId = drainageUser.UserId,
                        Description = "Specialized culvert, stormwater, and curb clearing team",
                        ContactNumber = "+94112999001",
                        Status = "AVAILABLE",
                        CreatedAt = DateTime.UtcNow,
                        UpdatedAt = DateTime.UtcNow
                    },
                    new Crew
                    {
                        CrewId = Guid.Parse("c0000000-0000-0000-0000-000000000002"),
                        CrewName = "Road Maintenance Crew Bravo",
                        CrewType = "ROAD",
                        CrewLeaderUserId = roadUser.UserId,
                        Description = "Asphalt patching, pavement, and pothole restoration team",
                        ContactNumber = "+94112999002",
                        Status = "AVAILABLE",
                        CreatedAt = DateTime.UtcNow,
                        UpdatedAt = DateTime.UtcNow
                    }
                );

                await context.SaveChangesAsync();
            }

            logger.LogInformation("Database seeded successfully.");
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "An error occurred while seeding the database.");
        }
    }
}
