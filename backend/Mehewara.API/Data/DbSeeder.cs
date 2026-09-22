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

            var wasteRole = await context.Roles
                .FirstAsync(r => r.RoleCode == "CREW_LEADER_WASTE");

            var electricalRole = await context.Roles
                .FirstAsync(r => r.RoleCode == "CREW_LEADER_ELECTRICAL");

            var environmentRole = await context.Roles
                .FirstAsync(r => r.RoleCode == "CREW_LEADER_ENVIRONMENT");


            // ============================================================
            // 3. SEED USERS (ADMIN, RESIDENT & ALL 5 CREW LEADERS)
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
                },

                new()
                {
                    UserId = Guid.Parse("a0000000-0000-0000-0000-000000000005"),
                    RoleId = wasteRole.RoleId,
                    FirstName = "Amara",
                    LastName = "Jayawardena",
                    Email = "crew.waste@mehewara.gov.lk",
                    PasswordHash = BCrypt.Net.BCrypt.HashPassword("Crew@123"),
                    PhoneNumber = "+94774567890",
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                },

                new()
                {
                    UserId = Guid.Parse("a0000000-0000-0000-0000-000000000006"),
                    RoleId = electricalRole.RoleId,
                    FirstName = "Priya",
                    LastName = "Dharmadasa",
                    Email = "crew.electrical@mehewara.gov.lk",
                    PasswordHash = BCrypt.Net.BCrypt.HashPassword("Crew@123"),
                    PhoneNumber = "+94775678901",
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                },

                new()
                {
                    UserId = Guid.Parse("a0000000-0000-0000-0000-000000000007"),
                    RoleId = environmentRole.RoleId,
                    FirstName = "Kumara",
                    LastName = "Wickramasinghe",
                    Email = "crew.environment@mehewara.gov.lk",
                    PasswordHash = BCrypt.Net.BCrypt.HashPassword("Crew@123"),
                    PhoneNumber = "+94776789012",
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
            // 4. SEED CREWS (ALL 5 TYPES WITH AVAILABLE & BUSY STATUSES)
            // ============================================================

            var drainageUser = await context.Users
                .FirstAsync(u => u.Email == "crew.drainage@mehewara.gov.lk");

            var roadUser = await context.Users
                .FirstAsync(u => u.Email == "crew.road@mehewara.gov.lk");

            var wasteUser = await context.Users
                .FirstAsync(u => u.Email == "crew.waste@mehewara.gov.lk");

            var electricalUser = await context.Users
                .FirstAsync(u => u.Email == "crew.electrical@mehewara.gov.lk");

            var environmentUser = await context.Users
                .FirstAsync(u => u.Email == "crew.environment@mehewara.gov.lk");

            var crewsToSeed = new List<Crew>
            {
                new()
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

                new()
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
                },

                new()
                {
                    CrewId = Guid.Parse("c0000000-0000-0000-0000-000000000003"),
                    CrewName = "Waste Management Charlie",
                    CrewType = "WASTE",
                    CrewLeaderUserId = wasteUser.UserId,
                    Description = "Solid waste management, illegal dumping clearance, and bulk refuse collection",
                    ContactNumber = "+94112999003",
                    Status = "AVAILABLE",
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                },

                new()
                {
                    CrewId = Guid.Parse("c0000000-0000-0000-0000-000000000004"),
                    CrewName = "Electrical Services Delta",
                    CrewType = "ELECTRICAL",
                    CrewLeaderUserId = electricalUser.UserId,
                    Description = "Municipal street lighting, distribution board repairs, and traffic light maintenance",
                    ContactNumber = "+94112999004",
                    Status = "BUSY",
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                },

                new()
                {
                    CrewId = Guid.Parse("c0000000-0000-0000-0000-000000000005"),
                    CrewName = "Environment Response Echo",
                    CrewType = "ENVIRONMENT",
                    CrewLeaderUserId = environmentUser.UserId,
                    Description = "Fallen tree removal, park maintenance, open drainage verge clearing, and landscaping hazards",
                    ContactNumber = "+94112999005",
                    Status = "AVAILABLE",
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                }
            };

            foreach (var crew in crewsToSeed)
            {
                if (!await context.Crews.AnyAsync(c => c.CrewId == crew.CrewId))
                {
                    context.Crews.Add(crew);
                }
            }

            await context.SaveChangesAsync();


            // ============================================================
            // 5. SEED PROBLEMS (ALL 4 PRIORITY TIERS & CREW TYPES)
            // ============================================================

            var problem1Id = Guid.Parse("b0000000-0000-0000-0000-000000000001");
            var problem2Id = Guid.Parse("b0000000-0000-0000-0000-000000000002");
            var problem3Id = Guid.Parse("b0000000-0000-0000-0000-000000000003");
            var problem4Id = Guid.Parse("b0000000-0000-0000-0000-000000000004");
            var problem5Id = Guid.Parse("b0000000-0000-0000-0000-000000000005");
            var problem6Id = Guid.Parse("b0000000-0000-0000-0000-000000000006");

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
                },

                new()
                {
                    ProblemId = problem3Id,
                    Title = "Burst water main causing severe roadway flooding",
                    Description = "High-pressure water main rupture submerging two lanes, eroding sub-base asphalt, and threatening nearby hospital access.",
                    Category = "DRAINAGE",
                    Latitude = 7.292500m,
                    Longitude = 80.634000m,
                    Address = "Peradeniya Road near Teaching Hospital, Kandy",
                    Priority = "CRITICAL",
                    PriorityScore = 95,
                    Status = "IDENTIFIED",
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                },

                new()
                {
                    ProblemId = problem4Id,
                    Title = "Fallen roadside tree blocking two-lane traffic",
                    Description = "Large mature tree uprooted after thunderstorm, completely blocking carriage way and bringing down telephone lines.",
                    Category = "ENVIRONMENT",
                    Latitude = 7.293100m,
                    Longitude = 80.637200m,
                    Address = "Near Victoria Park entrance, Kandy",
                    Priority = "HIGH",
                    PriorityScore = 70,
                    Status = "IDENTIFIED",
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                },

                new()
                {
                    ProblemId = problem5Id,
                    Title = "Minor pothole near residential access lane",
                    Description = "Surface asphalt deterioration causing shallow depression, low immediate safety risk to slow-moving local vehicles.",
                    Category = "ROAD",
                    Latitude = 7.294500m,
                    Longitude = 80.636000m,
                    Address = "Temple Road Lane 2, Kandy",
                    Priority = "LOW",
                    PriorityScore = 20,
                    Status = "IDENTIFIED",
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                },

                new()
                {
                    ProblemId = problem6Id,
                    Title = "Multiple streetlights inoperable along main transit corridor",
                    Description = "Series of consecutive street lamps failing, creating blind zones for pedestrians and night commuter buses. Paired with BUSY electrical crew.",
                    Category = "ELECTRICAL",
                    Latitude = 7.295200m,
                    Longitude = 80.639000m,
                    Address = "Station Road transit corridor, Kandy",
                    Priority = "MEDIUM",
                    PriorityScore = 50,
                    Status = "IDENTIFIED",
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                }
            };

            foreach (var problem in problemsToSeed)
            {
                if (!await context.Problems.AnyAsync(p => p.ProblemId == problem.ProblemId))
                {
                    context.Problems.Add(problem);
                }
            }

            await context.SaveChangesAsync();
            logger.LogInformation("Seeded problems successfully.");


            // ============================================================
            // 6. SEED REPORTS (LINKED REPORTS & UNASSIGNED FOR MEMBER 2)
            // ============================================================

            var residentUser = await context.Users
                .FirstAsync(u => u.Email == "resident@example.com");

            var reportsToSeed = new List<Report>
            {
                // ----------------------------------------------------
                // PROBLEM 1 REPORTS (DRAINAGE - HIGH)
                // ----------------------------------------------------
                new()
                {
                    ReportId = Guid.Parse("d0000000-0000-0000-0000-000000000001"),
                    ResidentId = residentUser.UserId,
                    ProblemId = problem1Id,
                    Description = "There is a huge amount of water covering the road near Central College. Cars are struggling to pass through.",
                    Category = "DRAINAGE",
                    Latitude = 7.290600m,
                    Longitude = 80.633700m,
                    Address = "Near Central College, Kandy",
                    Status = "PENDING",
                    CreatedAt = DateTime.UtcNow.AddHours(-6),
                    UpdatedAt = DateTime.UtcNow.AddHours(-6)
                },
                new()
                {
                    ReportId = Guid.Parse("d0000000-0000-0000-0000-000000000002"),
                    ResidentId = residentUser.UserId,
                    ProblemId = problem1Id,
                    Description = "The road near Central College is flooded after the rain. Vehicles are having difficulty getting through.",
                    Category = "DRAINAGE",
                    Latitude = 7.290620m,
                    Longitude = 80.633680m,
                    Address = "Near Central College, Kandy",
                    Status = "PENDING",
                    CreatedAt = DateTime.UtcNow.AddHours(-5),
                    UpdatedAt = DateTime.UtcNow.AddHours(-5)
                },
                new()
                {
                    ReportId = Guid.Parse("d0000000-0000-0000-0000-000000000003"),
                    ResidentId = residentUser.UserId,
                    ProblemId = problem1Id,
                    Description = "Water is collecting beside Central College. The roadside drain may be blocked.",
                    Category = "DRAINAGE",
                    Latitude = 7.290550m,
                    Longitude = 80.633750m,
                    Address = "Side road near Central College, Kandy",
                    Status = "PENDING",
                    CreatedAt = DateTime.UtcNow.AddHours(-4),
                    UpdatedAt = DateTime.UtcNow.AddHours(-4)
                },
                new()
                {
                    ReportId = Guid.Parse("d0000000-0000-0000-0000-000000000004"),
                    ResidentId = residentUser.UserId,
                    ProblemId = problem1Id,
                    Description = "There is water all over the road near Central College and traffic is moving very slowly.",
                    Category = "DRAINAGE",
                    Latitude = 7.290590m,
                    Longitude = 80.633710m,
                    Address = "Central College road, Kandy",
                    Status = "PENDING",
                    CreatedAt = DateTime.UtcNow.AddHours(-3),
                    UpdatedAt = DateTime.UtcNow.AddHours(-3)
                },

                // ----------------------------------------------------
                // PROBLEM 2 REPORTS (ROAD - MEDIUM)
                // ----------------------------------------------------
                new()
                {
                    ReportId = Guid.Parse("d0000000-0000-0000-0000-000000000005"),
                    ResidentId = residentUser.UserId,
                    ProblemId = problem2Id,
                    Description = "There is a large pothole on Main Street near the bus stop.",
                    Category = "ROAD",
                    Latitude = 7.291820m,
                    Longitude = 80.635210m,
                    Address = "Main Street near bus stop, Kandy",
                    Status = "PENDING",
                    CreatedAt = DateTime.UtcNow.AddHours(-5),
                    UpdatedAt = DateTime.UtcNow.AddHours(-5)
                },
                new()
                {
                    ReportId = Guid.Parse("d0000000-0000-0000-0000-000000000006"),
                    ResidentId = residentUser.UserId,
                    ProblemId = problem2Id,
                    Description = "Vehicles are hitting a big pothole on Main Street close to the bus stop.",
                    Category = "ROAD",
                    Latitude = 7.291850m,
                    Longitude = 80.635190m,
                    Address = "Main Street near bus stop, Kandy",
                    Status = "PENDING",
                    CreatedAt = DateTime.UtcNow.AddHours(-2),
                    UpdatedAt = DateTime.UtcNow.AddHours(-2)
                },

                // ----------------------------------------------------
                // UNASSIGNED REPORTS (MEMBER 2 CONSOLIDATION AGENT TESTS)
                // ----------------------------------------------------
                new()
                {
                    ReportId = Guid.Parse("d0000000-0000-0000-0000-000000000007"),
                    ResidentId = residentUser.UserId,
                    ProblemId = null,
                    Description = "A large tree has fallen across the road near the public park and is blocking vehicles.",
                    Category = "ENVIRONMENT",
                    Latitude = 7.293100m,
                    Longitude = 80.637200m,
                    Address = "Near public park, Kandy",
                    Status = "PENDING",
                    CreatedAt = DateTime.UtcNow.AddHours(-1),
                    UpdatedAt = DateTime.UtcNow.AddHours(-1)
                },
                new()
                {
                    ReportId = Guid.Parse("d0000000-0000-0000-0000-000000000008"),
                    ResidentId = residentUser.UserId,
                    ProblemId = null,
                    Description = "Garbage has not been collected for several days around the market area.",
                    Category = "WASTE",
                    Latitude = 7.294000m,
                    Longitude = 80.638100m,
                    Address = "Market area, Kandy",
                    Status = "PENDING",
                    CreatedAt = DateTime.UtcNow.AddMinutes(-30),
                    UpdatedAt = DateTime.UtcNow.AddMinutes(-30)
                },

                // ----------------------------------------------------
                // PROBLEM 3 REPORTS (DRAINAGE - CRITICAL: BURST WATER MAIN)
                // ----------------------------------------------------
                new()
                {
                    ReportId = Guid.Parse("d0000000-0000-0000-0000-000000000009"),
                    ResidentId = residentUser.UserId,
                    ProblemId = problem3Id,
                    Description = "Water is gushing out from under the pavement on Peradeniya Road! The road is becoming a river.",
                    Category = "DRAINAGE",
                    Latitude = 7.292510m,
                    Longitude = 80.634020m,
                    Address = "Peradeniya Road near Teaching Hospital, Kandy",
                    Status = "PENDING",
                    CreatedAt = DateTime.UtcNow.AddHours(-2),
                    UpdatedAt = DateTime.UtcNow.AddHours(-2)
                },
                new()
                {
                    ReportId = Guid.Parse("d0000000-0000-0000-0000-000000000010"),
                    ResidentId = residentUser.UserId,
                    ProblemId = problem3Id,
                    Description = "Burst pipe near the hospital entrance. Water pressure is lifting chunks of bitumen. Cars cannot pass.",
                    Category = "DRAINAGE",
                    Latitude = 7.292490m,
                    Longitude = 80.633980m,
                    Address = "Peradeniya Road near Teaching Hospital, Kandy",
                    Status = "PENDING",
                    CreatedAt = DateTime.UtcNow.AddMinutes(-90),
                    UpdatedAt = DateTime.UtcNow.AddMinutes(-90)
                },
                new()
                {
                    ReportId = Guid.Parse("d0000000-0000-0000-0000-000000000011"),
                    ResidentId = residentUser.UserId,
                    ProblemId = problem3Id,
                    Description = "Massive water pipe break on Peradeniya Road. Hospital ambulances are having to divert.",
                    Category = "DRAINAGE",
                    Latitude = 7.292530m,
                    Longitude = 80.634010m,
                    Address = "Peradeniya Road near Teaching Hospital, Kandy",
                    Status = "PENDING",
                    CreatedAt = DateTime.UtcNow.AddMinutes(-60),
                    UpdatedAt = DateTime.UtcNow.AddMinutes(-60)
                },

                // ----------------------------------------------------
                // PROBLEM 4 REPORT (ENVIRONMENT - HIGH: FALLEN TREE)
                // ----------------------------------------------------
                new()
                {
                    ReportId = Guid.Parse("d0000000-0000-0000-0000-000000000012"),
                    ResidentId = residentUser.UserId,
                    ProblemId = problem4Id,
                    Description = "Large tree fell across the main entrance to Victoria Park blocking all vehicular traffic.",
                    Category = "ENVIRONMENT",
                    Latitude = 7.293100m,
                    Longitude = 80.637200m,
                    Address = "Near Victoria Park entrance, Kandy",
                    Status = "PENDING",
                    CreatedAt = DateTime.UtcNow.AddHours(-3),
                    UpdatedAt = DateTime.UtcNow.AddHours(-3)
                },

                // ----------------------------------------------------
                // PROBLEM 5 REPORT (ROAD - LOW: MINOR POTHOLE)
                // ----------------------------------------------------
                new()
                {
                    ReportId = Guid.Parse("d0000000-0000-0000-0000-000000000013"),
                    ResidentId = residentUser.UserId,
                    ProblemId = problem5Id,
                    Description = "Small shallow pothole developing at the turn into Temple Road Lane 2. Please patch before it widens.",
                    Category = "ROAD",
                    Latitude = 7.294500m,
                    Longitude = 80.636000m,
                    Address = "Temple Road Lane 2, Kandy",
                    Status = "PENDING",
                    CreatedAt = DateTime.UtcNow.AddHours(-4),
                    UpdatedAt = DateTime.UtcNow.AddHours(-4)
                },

                // ----------------------------------------------------
                // PROBLEM 6 REPORTS (ELECTRICAL - MEDIUM: STREETLIGHTS)
                // ----------------------------------------------------
                new()
                {
                    ReportId = Guid.Parse("d0000000-0000-0000-0000-000000000014"),
                    ResidentId = residentUser.UserId,
                    ProblemId = problem6Id,
                    Description = "Street lights from Station Road bus stand to the rail crossing have been dead for two nights.",
                    Category = "ELECTRICAL",
                    Latitude = 7.295210m,
                    Longitude = 80.639010m,
                    Address = "Station Road transit corridor, Kandy",
                    Status = "PENDING",
                    CreatedAt = DateTime.UtcNow.AddHours(-5),
                    UpdatedAt = DateTime.UtcNow.AddHours(-5)
                },
                new()
                {
                    ReportId = Guid.Parse("d0000000-0000-0000-0000-000000000015"),
                    ResidentId = residentUser.UserId,
                    ProblemId = problem6Id,
                    Description = "Very dark along Station Road corridor. Extremely dangerous for pedestrians crossing at night.",
                    Category = "ELECTRICAL",
                    Latitude = 7.295190m,
                    Longitude = 80.638990m,
                    Address = "Station Road transit corridor, Kandy",
                    Status = "PENDING",
                    CreatedAt = DateTime.UtcNow.AddHours(-2),
                    UpdatedAt = DateTime.UtcNow.AddHours(-2)
                }
            };

            foreach (var report in reportsToSeed)
            {
                if (!await context.Reports.AnyAsync(r => r.ReportId == report.ReportId))
                {
                    context.Reports.Add(report);
                }
            }

            await context.SaveChangesAsync();
            logger.LogInformation("Seeded reports successfully.");


            // ============================================================
            // 7. SEED ACTIVE WORK ORDER FOR BUSY CREW (ELECTRICAL DELTA)
            // ============================================================

            var busyWorkOrderId = Guid.Parse("w0000000-0000-0000-0000-000000000001");
            if (!await context.WorkOrders.AnyAsync(w => w.WorkOrderId == busyWorkOrderId))
            {
                var busyWorkOrder = new WorkOrder
                {
                    WorkOrderId = busyWorkOrderId,
                    ProblemId = problem6Id,
                    CrewId = Guid.Parse("c0000000-0000-0000-0000-000000000004"), // Electrical Services Delta
                    Priority = "HIGH",
                    Title = "Emergency feeder box repair at Clock Tower junction",
                    Instructions = "Inspect and repair short-circuited municipal street feeder box.",
                    Status = "IN_PROGRESS",
                    AssignedAt = DateTime.UtcNow.AddHours(-2),
                    StartedAt = DateTime.UtcNow.AddHours(-1),
                    CreatedAt = DateTime.UtcNow.AddHours(-2),
                    UpdatedAt = DateTime.UtcNow.AddHours(-1)
                };

                context.WorkOrders.Add(busyWorkOrder);
                await context.SaveChangesAsync();
                logger.LogInformation("Seeded active work order for busy crew.");
            }


            // ============================================================
            // 8. SEED WORKFLOW RUNS & AGENT 3 WORKFLOW EVENTS
            // ============================================================

            // ------------------------------------------------------------
            // SCENARIO A: Happy Path (Problem 1 -> Drainage Alpha AVAILABLE)
            // ------------------------------------------------------------
            var workflowRun1Id = Guid.Parse("f0000000-0000-0000-0000-000000000001");
            if (!await context.WorkflowRuns.AnyAsync(w => w.WorkflowRunId == workflowRun1Id))
            {
                var workflowRun1 = new WorkflowRun
                {
                    WorkflowRunId = workflowRun1Id,
                    ReportId = Guid.Parse("d0000000-0000-0000-0000-000000000001"),
                    ProblemId = problem1Id,
                    CurrentStage = "WAITING_FOR_APPROVAL",
                    Status = "WAITING",
                    StartedAt = DateTime.UtcNow.AddHours(-2),
                    CreatedAt = DateTime.UtcNow.AddHours(-2),
                    UpdatedAt = DateTime.UtcNow.AddMinutes(-10)
                };

                context.WorkflowRuns.Add(workflowRun1);
                await context.SaveChangesAsync();
            }

            var workflowEvent1Id = Guid.Parse("e0000000-0000-0000-0000-000000000001");
            if (!await context.WorkflowEvents.AnyAsync(e => e.WorkflowEventId == workflowEvent1Id))
            {
                var recommendationJson1 = """
                {
                  "problemId": "b0000000-0000-0000-0000-000000000001",
                  "priority": "HIGH",
                  "priorityScore": 75,
                  "priorityReasons": [
                    "Public road affected with persistent stormwater accumulation",
                    "Risk of traffic bottleneck during peak hours near Central College",
                    "Multiple resident complaints confirm recurring drain blockage"
                  ],
                  "requiredCrewType": "DRAINAGE",
                  "recommendedCrewId": "c0000000-0000-0000-0000-000000000001",
                  "recommendationReason": "Crew type matches DRAINAGE requirement and crew is currently AVAILABLE with zero active jobs."
                }
                """;

                var validationJson1 = """
                {
                  "status": "VALID",
                  "issues": []
                }
                """;

                var workflowEvent1 = new WorkflowEvent
                {
                    WorkflowEventId = workflowEvent1Id,
                    WorkflowRunId = workflowRun1Id,
                    AgentName = "PriorityCrewAgent",
                    Stage = "PRIORITIZATION",
                    Status = "COMPLETED",
                    OutputData = recommendationJson1,
                    ValidationResult = validationJson1,
                    StartedAt = DateTime.UtcNow.AddHours(-2),
                    CompletedAt = DateTime.UtcNow.AddHours(-2).AddSeconds(15)
                };

                context.WorkflowEvents.Add(workflowEvent1);
                await context.SaveChangesAsync();
                logger.LogInformation("Seeded Agent 3 recommendation event for Problem 1 (Available crew).");
            }

            // ------------------------------------------------------------
            // SCENARIO B: Edge Case (Problem 6 -> Electrical Delta BUSY)
            // ------------------------------------------------------------
            var workflowRun2Id = Guid.Parse("f0000000-0000-0000-0000-000000000002");
            if (!await context.WorkflowRuns.AnyAsync(w => w.WorkflowRunId == workflowRun2Id))
            {
                var workflowRun2 = new WorkflowRun
                {
                    WorkflowRunId = workflowRun2Id,
                    ReportId = Guid.Parse("d0000000-0000-0000-0000-000000000014"),
                    ProblemId = problem6Id,
                    CurrentStage = "WAITING_FOR_APPROVAL",
                    Status = "WAITING",
                    StartedAt = DateTime.UtcNow.AddHours(-1),
                    CreatedAt = DateTime.UtcNow.AddHours(-1),
                    UpdatedAt = DateTime.UtcNow.AddMinutes(-5)
                };

                context.WorkflowRuns.Add(workflowRun2);
                await context.SaveChangesAsync();
            }

            var workflowEvent2Id = Guid.Parse("e0000000-0000-0000-0000-000000000002");
            if (!await context.WorkflowEvents.AnyAsync(e => e.WorkflowEventId == workflowEvent2Id))
            {
                var recommendationJson2 = """
                {
                  "problemId": "b0000000-0000-0000-0000-000000000006",
                  "priority": "MEDIUM",
                  "priorityScore": 50,
                  "priorityReasons": [
                    "Dark transit corridor creates pedestrian safety hazard",
                    "High night traffic area with compromised visibility"
                  ],
                  "requiredCrewType": "ELECTRICAL",
                  "recommendedCrewId": "c0000000-0000-0000-0000-000000000004",
                  "recommendationReason": "Electrical Services Unit Delta is qualified for electrical maintenance; however, crew is currently BUSY on active work order."
                }
                """;

                var validationJson2 = """
                {
                  "status": "REVISION_REQUIRED",
                  "issues": [
                    "Recommended crew 'c0000000-0000-0000-0000-000000000004' is BUSY"
                  ]
                }
                """;

                var workflowEvent2 = new WorkflowEvent
                {
                    WorkflowEventId = workflowEvent2Id,
                    WorkflowRunId = workflowRun2Id,
                    AgentName = "PriorityCrewAgent",
                    Stage = "PRIORITIZATION",
                    Status = "COMPLETED",
                    OutputData = recommendationJson2,
                    ValidationResult = validationJson2,
                    StartedAt = DateTime.UtcNow.AddHours(-1),
                    CompletedAt = DateTime.UtcNow.AddHours(-1).AddSeconds(12)
                };

                context.WorkflowEvents.Add(workflowEvent2);
                await context.SaveChangesAsync();
                logger.LogInformation("Seeded Agent 3 recommendation event for Problem 6 (Busy crew conflict).");
            }


            // ============================================================
            // 9. FINAL COMPLETION LOG
            // ============================================================

            logger.LogInformation(
                "Database seeded successfully with all roles, users, 5 specialized crews, multi-tier problems, linked/unassigned reports, busy work orders, and Agent 3 recommendation events.");
        }
        catch (Exception ex)
        {
            logger.LogError(
                ex,
                "An error occurred while seeding the database.");
            throw;
        }
    }
}