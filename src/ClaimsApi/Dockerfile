FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY src/ClaimsApi/ClaimsApi.csproj src/ClaimsApi/
RUN dotnet restore src/ClaimsApi/ClaimsApi.csproj
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
