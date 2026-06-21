FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ClaimsApi.sln .
COPY src/ClaimsApi/ClaimsApi.csproj src/ClaimsApi/
COPY tests/ClaimsApi.Tests/ClaimsApi.Tests.csproj tests/ClaimsApi.Tests/
RUN dotnet restore ClaimsApi.sln
COPY src/ClaimsApi/ src/ClaimsApi/
RUN dotnet publish src/ClaimsApi/ClaimsApi.csproj -c Release -o /app

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
RUN adduser --disabled-password --gecos "" appuser
COPY --from=build /app .
USER appuser
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
ENTRYPOINT ["dotnet", "ClaimsApi.dll"]
