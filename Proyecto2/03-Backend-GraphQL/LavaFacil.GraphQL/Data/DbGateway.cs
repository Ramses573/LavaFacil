using System.Data;
using System.Globalization;
using LavaFacil.GraphQL.Security;
using Microsoft.Data.SqlClient;

namespace LavaFacil.GraphQL.Data;

// Gateway único: conserva la interfaz de Ramsés y los controles por rol de Rachel.
public sealed class DbGateway(IConfiguration configuration, RequestIdentity identity)
{
    private SqlConnection Connection(bool login, bool publicRead)
    {
        var role = "Invitado";
        if (!login && publicRead)
            role = identity.Current?.Rol switch
            {
                "Cliente" => "Cliente",
                "Empleado" or "Administrador" => "Empleado",
                _ => "Invitado"
            };
        if (!login && !publicRead)
        {
            identity.RequireStaff();
            role = "Empleado";
        }
        var value = configuration.GetConnectionString(role);
        if (string.IsNullOrWhiteSpace(value))
            throw new InvalidOperationException($"Falta configurar la conexión {role} localmente.");
        return new SqlConnection(value);
    }

    private static SqlCommand Command(SqlConnection connection, string procedure,
        IReadOnlyDictionary<string, object?>? parameters)
    {
        // Los nombres proceden de los resolvers, nunca de argumentos GraphQL.
        if (procedure.Any(c => !char.IsAsciiLetterOrDigit(c) && c != '_'))
            throw new ArgumentException("Nombre de procedimiento inválido.", nameof(procedure));
        var command = new SqlCommand("dbo." + procedure, connection)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 30
        };
        if (parameters is not null)
            foreach (var (name, value) in parameters)
                command.Parameters.AddWithValue(name.StartsWith('@') ? name : "@" + name, value ?? DBNull.Value);
        return command;
    }

    public async Task<List<T>> QueryAsync<T>(string procedure,
        IReadOnlyDictionary<string, object?>? parameters = null, bool login = false, bool publicRead = false) where T : new()
    {
        await using var connection = Connection(login, publicRead);
        await using var command = Command(connection, procedure, parameters);
        await connection.OpenAsync();
        await using var reader = await command.ExecuteReaderAsync();
        var properties = typeof(T).GetProperties().Where(p => p.CanWrite)
            .ToDictionary(p => p.Name, StringComparer.OrdinalIgnoreCase);
        var rows = new List<T>();
        while (await reader.ReadAsync())
        {
            var row = new T();
            for (var i = 0; i < reader.FieldCount; i++)
            {
                if (!properties.TryGetValue(reader.GetName(i), out var property) || reader.IsDBNull(i)) continue;
                var type = Nullable.GetUnderlyingType(property.PropertyType) ?? property.PropertyType;
                property.SetValue(row, Convert.ChangeType(reader.GetValue(i), type, CultureInfo.InvariantCulture));
            }
            rows.Add(row);
        }
        return rows;
    }

    public async Task ExecuteAsync(string procedure, IReadOnlyDictionary<string, object?> parameters)
    {
        await using var connection = Connection(login: false, publicRead: false);
        await using var command = Command(connection, procedure, parameters);
        await connection.OpenAsync();
        await command.ExecuteNonQueryAsync();
    }
}
