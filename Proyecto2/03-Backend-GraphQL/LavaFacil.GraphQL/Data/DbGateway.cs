using Microsoft.Data.SqlClient;
using System.Data;
using System.Reflection;
using LavaFacil.GraphQL.Security;

namespace LavaFacil.GraphQL.Data;

public sealed class DbGateway(IConfiguration configuration, RequestIdentity identity)
{
    private string ConnectionFor(bool login = false, bool publicRead = false)
    {
        var key = login || publicRead ? "Invitado" : identity.Current?.Rol == "Cliente" ? "Cliente" : "Empleado";
        var connection = configuration.GetConnectionString(key);
        if (string.IsNullOrWhiteSpace(connection)) throw new GraphQLException($"Falta configurar ConnectionStrings:{key}.");
        return connection;
    }

    public async Task<List<T>> QueryAsync<T>(string procedure, IReadOnlyDictionary<string, object?>? parameters = null, bool login = false, bool publicRead = false) where T : new()
    {
        await using var connection = new SqlConnection(ConnectionFor(login, publicRead));
        await using var command = BuildCommand(connection, procedure, parameters);
        await connection.OpenAsync();
        await using var reader = await command.ExecuteReaderAsync();
        var result = new List<T>();
        var properties = typeof(T).GetProperties(BindingFlags.Public | BindingFlags.Instance).Where(p => p.CanWrite)
            .ToDictionary(p => p.Name, StringComparer.OrdinalIgnoreCase);
        while (await reader.ReadAsync())
        {
            var item = new T();
            for (var i = 0; i < reader.FieldCount; i++)
            {
                if (!properties.TryGetValue(reader.GetName(i), out var property) || await reader.IsDBNullAsync(i)) continue;
                var target = Nullable.GetUnderlyingType(property.PropertyType) ?? property.PropertyType;
                property.SetValue(item, Convert.ChangeType(reader.GetValue(i), target));
            }
            result.Add(item);
        }
        return result;
    }

    public async Task ExecuteAsync(string procedure, IReadOnlyDictionary<string, object?> parameters)
    {
        await using var connection = new SqlConnection(ConnectionFor());
        await using var command = BuildCommand(connection, procedure, parameters);
        await connection.OpenAsync();
        await command.ExecuteNonQueryAsync();
    }

    private static SqlCommand BuildCommand(SqlConnection connection, string procedure, IReadOnlyDictionary<string, object?>? parameters)
    {
        var command = new SqlCommand(procedure, connection) { CommandType = CommandType.StoredProcedure, CommandTimeout = 30 };
        if (parameters is not null)
            foreach (var (name, value) in parameters)
                command.Parameters.AddWithValue(name.StartsWith('@') ? name : $"@{name}", value ?? DBNull.Value);
        return command;
    }
}
