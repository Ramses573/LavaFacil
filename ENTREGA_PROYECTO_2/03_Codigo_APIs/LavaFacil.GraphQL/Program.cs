using LavaFacil.GraphQL.Data;
using LavaFacil.GraphQL.GraphQL;
using LavaFacil.GraphQL.Security;
using Microsoft.AspNetCore.DataProtection;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddHttpContextAccessor();
builder.Services.AddDataProtection()
    .SetApplicationName("LavaFacil.GraphQL")
    .PersistKeysToFileSystem(new DirectoryInfo(System.IO.Path.Combine(builder.Environment.ContentRootPath, "keys")));
builder.Services.AddSingleton<TokenService>();
builder.Services.AddScoped<RequestIdentity>();
builder.Services.AddScoped<DbGateway>();
builder.Services.AddGraphQLServer().AddQueryType<Query>().AddMutationType<Mutation>()
    .AddTypeExtension<RachelQueries>();

var app = builder.Build();
app.UseHttpsRedirection();
app.MapGet("/", () => Results.Redirect("/graphql"));
app.MapGraphQL("/graphql");
app.Run();
