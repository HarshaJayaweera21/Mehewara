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

            // ============================================================
            // 1. SEED ROLES
            // ============================================================

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


            // ============================================================
            // 2. GET REQUIRED ROLES
            // ============================================================

            var adminRole = await context.Roles
                .FirstAsync(r => r.RoleCode == "ADMIN");

            var residentRole = await context.Roles
                .FirstAsync(r => r.RoleCode == "RESIDENT");

            var drainageRole = await context.Roles
                .FirstAsync(r => r.RoleCode == "CREW_LEADER_DRAINAGE");

            var roadRole = await context.Roles
                .FirstAsync(r => r.RoleCode == "CREW_LEADER_ROAD");


            // ============================================================
            // 3. SEED DEFAULT TEST USERS
            // ============================================================

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


            // ============================================================
            // 4. SEED CREWS
            // ============================================================

            if (!await context.Crews.AnyAsync())
            {
                var drainageUser = await context.Users
                    .FirstAsync(u => u.Email == "crew.drainage@mehewara.gov.lk");

                var roadUser = await context.Users
                    .FirstAsync(u => u.Email == "crew.road@mehewara.gov.lk");

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


            // ============================================================
            // 5. SEED PROBLEMS
            // ============================================================
            //
            // Current relationship:
            //
            // Problem 1 -----> Many Reports
            //
            // Report has:
            //     ProblemId = nullable FK
            //
            // There is NO ReportProblem join table.
            // ============================================================

            var problem1Id =
                Guid.Parse("b0000000-0000-0000-0000-000000000001");

            var problem2Id =
                Guid.Parse("b0000000-0000-0000-0000-000000000002");

            if (!await context.Problems.AnyAsync())
            {
                var problemsToSeed = new List<Problem>
                {
                    new()
                    {
                        ProblemId = problem1Id,
                        Title = "Blocked roadside drain near Central College",
                        Description = "Multiple resident reports describe water accumulating on and beside the road near Central College, indicating a possible drainage obstruction.",
                        Category = "DRAINAGE",
                        Latitude = 7.290571m,
                        Longitude = 80.633726m,
                        Address = "Near Central College, Kandy",
                        Priority = "HIGH",
                        PriorityScore = 75,
                        Status = "IDENTIFIED",
                        CreatedAt = DateTime.UtcNow,
                        UpdatedAt = DateTime.UtcNow
                    },

                    new()
                    {
                        ProblemId = problem2Id,
                        Title = "Large pothole on Main Street",
                        Description = "Multiple reports describe a large pothole on Main Street near the bus stop, affecting vehicles using the road.",
                        Category = "ROAD",
                        Latitude = 7.291820m,
                        Longitude = 80.635210m,
                        Address = "Main Street near bus stop, Kandy",
                        Priority = "MEDIUM",
                        PriorityScore = 55,
                        Status = "IDENTIFIED",
                        CreatedAt = DateTime.UtcNow,
                        UpdatedAt = DateTime.UtcNow
                    }
                };

                context.Problems.AddRange(problemsToSeed);

                await context.SaveChangesAsync();

                logger.LogInformation("Seeded {Count} problems.", problemsToSeed.Count);
            }


            // ============================================================
            // 6. SEED REPORTS
            // ============================================================
            //
            // R001-R004 -> Problem 1
            // R005-R006 -> Problem 2
            // R007-R008 -> NULL
            //
            // The NULL reports are intentionally left unassigned so
            // Member 2 can test the Problem Consolidation workflow.
            // ============================================================

            if (!await context.Reports.AnyAsync())
            {
                var residentUser = await context.Users
                    .FirstAsync(u => u.Email == "resident@example.com");

                var reportsToSeed = new List<Report>
                {
                    // ----------------------------------------------------
                    // PROBLEM 1 REPORTS
                    // ----------------------------------------------------

                    new()
                    {
                        ReportId = Guid.Parse(
                            "d0000000-0000-0000-0000-000000000001"),

                        ResidentId = residentUser.UserId,

                        ProblemId = problem1Id,

                        Description =
                            "There is a huge amount of water covering the road near Central College. Cars are struggling to pass through.",

                        Category = "DRAINAGE",

                        Latitude = 7.290600m,
                        Longitude = 80.633700m,

                        Address =
                            "Near Central College, Kandy",

                        Status = "PENDING",

                        CreatedAt = DateTime.UtcNow.AddHours(-6),
                        UpdatedAt = DateTime.UtcNow.AddHours(-6)
                    },

                    new()
                    {
                        ReportId = Guid.Parse(
                            "d0000000-0000-0000-0000-000000000002"),

                        ResidentId = residentUser.UserId,

                        ProblemId = problem1Id,

                        Description =
                            "The road near Central College is flooded after the rain. Vehicles are having difficulty getting through.",

                        Category = "DRAINAGE",

                        Latitude = 7.290620m,
                        Longitude = 80.633680m,

                        Address =
                            "Near Central College, Kandy",

                        Status = "PENDING",

                        CreatedAt = DateTime.UtcNow.AddHours(-5),
                        UpdatedAt = DateTime.UtcNow.AddHours(-5)
                    },

                    new()
                    {
                        ReportId = Guid.Parse(
                            "d0000000-0000-0000-0000-000000000003"),

                        ResidentId = residentUser.UserId,

                        ProblemId = problem1Id,

                        Description =
                            "Water is collecting beside Central College. The roadside drain may be blocked.",

                        Category = "DRAINAGE",

                        Latitude = 7.290550m,
                        Longitude = 80.633750m,

                        Address =
                            "Side road near Central College, Kandy",

                        Status = "PENDING",

                        CreatedAt = DateTime.UtcNow.AddHours(-4),
                        UpdatedAt = DateTime.UtcNow.AddHours(-4)
                    },

                    new()
                    {
                        ReportId = Guid.Parse(
                            "d0000000-0000-0000-0000-000000000004"),

                        ResidentId = residentUser.UserId,

                        ProblemId = problem1Id,

                        Description =
                            "There is water all over the road near Central College and traffic is moving very slowly.",

                        Category = "DRAINAGE",

                        Latitude = 7.290590m,
                        Longitude = 80.633710m,

                        Address =
                            "Central College road, Kandy",

                        Status = "PENDING",

                        CreatedAt = DateTime.UtcNow.AddHours(-3),
                        UpdatedAt = DateTime.UtcNow.AddHours(-3)
                    },


                    // ----------------------------------------------------
                    // PROBLEM 2 REPORTS
                    // ----------------------------------------------------

                    new()
                    {
                        ReportId = Guid.Parse(
                            "d0000000-0000-0000-0000-000000000005"),

                        ResidentId = residentUser.UserId,

                        ProblemId = problem2Id,

                        Description =
                            "There is a large pothole on Main Street near the bus stop.",

                        Category = "ROAD",

                        Latitude = 7.291820m,
                        Longitude = 80.635210m,

                        Address =
                            "Main Street near bus stop, Kandy",

                        Status = "PENDING",

                        CreatedAt = DateTime.UtcNow.AddHours(-5),
                        UpdatedAt = DateTime.UtcNow.AddHours(-5)
                    },

                    new()
                    {
                        ReportId = Guid.Parse(
                            "d0000000-0000-0000-0000-000000000006"),

                        ResidentId = residentUser.UserId,

                        ProblemId = problem2Id,

                        Description =
                            "Vehicles are hitting a big pothole on Main Street close to the bus stop.",

                        Category = "ROAD",

                        Latitude = 7.291850m,
                        Longitude = 80.635190m,

                        Address =
                            "Main Street near bus stop, Kandy",

                        Status = "PENDING",

                        CreatedAt = DateTime.UtcNow.AddHours(-2),
                        UpdatedAt = DateTime.UtcNow.AddHours(-2)
                    },


                    // ----------------------------------------------------
                    // UNASSIGNED REPORT
                    // ----------------------------------------------------
                    // This should be processed by the Problem
                    // Consolidation Agent and may result in CREATE_NEW.
                    // ----------------------------------------------------

                    new()
                    {
                        ReportId = Guid.Parse(
                            "d0000000-0000-0000-0000-000000000007"),

                        ResidentId = residentUser.UserId,

                        ProblemId = null,

                        Description =
                            "A large tree has fallen across the road near the public park and is blocking vehicles.",

                        Category = "ENVIRONMENT",

                        Latitude = 7.293100m,
                        Longitude = 80.637200m,

                        Address =
                            "Near public park, Kandy",

                        Status = "PENDING",

                        CreatedAt = DateTime.UtcNow.AddHours(-1),
                        UpdatedAt = DateTime.UtcNow.AddHours(-1)
                    },


                    // ----------------------------------------------------
                    // ANOTHER UNASSIGNED REPORT
                    // ----------------------------------------------------
                    // Also intentionally has ProblemId = null.
                    // ----------------------------------------------------

                    new()
                    {
                        ReportId = Guid.Parse(
                            "d0000000-0000-0000-0000-000000000008"),

                        ResidentId = residentUser.UserId,

                        ProblemId = null,

                        Description =
                            "Garbage has not been collected for several days around the market area.",

                        Category = "WASTE",

                        Latitude = 7.294000m,
                        Longitude = 80.638100m,

                        Address =
                            "Market area, Kandy",

                        Status = "PENDING",

                        CreatedAt = DateTime.UtcNow.AddMinutes(-30),
                        UpdatedAt = DateTime.UtcNow.AddMinutes(-30)
                    }
                };

                context.Reports.AddRange(reportsToSeed);

                await context.SaveChangesAsync();

                logger.LogInformation("Seeded {Count} reports.", reportsToSeed.Count);
            }


            // ============================================================
            // 7. FINAL MESSAGE
            // ============================================================

            logger.LogInformation(
                "Database seeded successfully with roles, users, crews, problems and reports.");
        }
        catch (Exception ex)
        {
            logger.LogError(
                ex,
                "An error occurred while seeding the database.");
        }
    }
}