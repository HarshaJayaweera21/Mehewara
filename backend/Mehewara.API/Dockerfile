FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

COPY backend/Mehewara.API/Mehewara.API.csproj backend/Mehewara.API/
RUN dotnet restore backend/Mehewara.API/Mehewara.API.csproj

COPY backend/Mehewara.API/ backend/Mehewara.API/
RUN dotnet publish backend/Mehewara.API/Mehewara.API.csproj \
    --configuration Release \
    --output /app/publish \
    --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "Mehewara.API.dll"]
