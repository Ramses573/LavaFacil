#Requires -Version 5.1
<#
    Configura el correo saliente de LavaFacil.
    - Guarda Data/correo.dpapi cifrado con DPAPI del usuario actual de Windows.
    - Nunca escribe la clave en la linea de comandos ni la imprime.
    - Envia un correo de prueba antes de guardar la configuracion.

    Uso:
        powershell -ExecutionPolicy Bypass -File Tools\Configurar-Correo.ps1
        powershell -ExecutionPolicy Bypass -File Tools\Configurar-Correo.ps1 -Host smtp.gmail.com -Port 587 -Usuario cuenta@gmail.com -Remitente cuenta@gmail.com -Nombre "LavaFacil"
#>
[CmdletBinding()]
param(
    [Alias('Host')]
    [string]$Servidor,
    [int]$Port = 0,
    [string]$Usuario,
    [string]$Remitente,
    [string]$Nombre = 'LavaFacil'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Security

function Leer-Valor {
    param(
        [Parameter(Mandatory = $true)][string]$Etiqueta,
        [string]$ValorActual
    )
    if (-not [string]::IsNullOrWhiteSpace($ValorActual)) { return $ValorActual.Trim() }
    $respuesta = Read-Host $Etiqueta
    if ([string]::IsNullOrWhiteSpace($respuesta)) { throw "El valor '$Etiqueta' es obligatorio." }
    return $respuesta.Trim()
}

function Leer-Puerto {
    param([int]$ValorActual)
    if ($ValorActual -gt 0) {
        if ($ValorActual -gt 65535) { throw 'El puerto debe ser un numero entre 1 y 65535.' }
        return $ValorActual
    }
    $texto = Read-Host 'Puerto SMTP [587]'
    if ([string]::IsNullOrWhiteSpace($texto)) { return 587 }
    $numero = 0
    if (-not [int]::TryParse($texto.Trim(), [ref]$numero) -or $numero -lt 1 -or $numero -gt 65535) {
        throw 'El puerto debe ser un numero entre 1 y 65535.'
    }
    return $numero
}

$servidorFinal = Leer-Valor -Etiqueta 'Servidor SMTP (ejemplo: smtp.gmail.com)' -ValorActual $Servidor
$puertoFinal = Leer-Puerto -ValorActual $Port
$usuarioFinal = Leer-Valor -Etiqueta 'Usuario SMTP (cuenta de correo)' -ValorActual $Usuario
$remitenteFinal = Leer-Valor -Etiqueta 'Remitente (correo visible del envio)' -ValorActual $Remitente
if ([string]::IsNullOrWhiteSpace($Nombre)) { $Nombre = 'LavaFacil' }
$nombreFinal = $Nombre.Trim()

try {
    $direccion = New-Object System.Net.Mail.MailAddress($remitenteFinal)
} catch {
    throw 'El remitente no es un correo electronico valido.'
}
if ($direccion.Address -ne $remitenteFinal) {
    throw 'El remitente debe ser una direccion de correo simple, sin nombre visible.'
}

if ($servidorFinal -eq 'smtp.gmail.com' -and $remitenteFinal -ne $usuarioFinal) {
    throw 'En Gmail el remitente debe ser igual al usuario de la cuenta.'
}

Write-Host ''
Write-Host 'Se pedira la clave SMTP. No se mostrara en pantalla ni se guardara sin cifrar.' -ForegroundColor Cyan
$seguro = Read-Host 'Clave de aplicacion SMTP' -AsSecureString
$puntero = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($seguro)
try {
    $clave = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($puntero)
} finally {
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($puntero)
    $seguro = $null
}
if ([string]::IsNullOrEmpty($clave)) { throw 'La clave SMTP es obligatoria.' }

$mensaje = $null
$cliente = $null
try {
    $mensaje = New-Object System.Net.Mail.MailMessage
    $mensaje.From = New-Object System.Net.Mail.MailAddress($remitenteFinal, $nombreFinal)
    [void]$mensaje.To.Add($remitenteFinal)
    $mensaje.Subject = 'LavaFacil - Prueba de correo saliente'
    $mensaje.SubjectEncoding = [System.Text.Encoding]::UTF8
    $mensaje.BodyEncoding = [System.Text.Encoding]::UTF8
    $mensaje.IsBodyHtml = $false
    $mensaje.Body = "Este es un mensaje de prueba de LavaFacil.`r`n`r`nSi lo recibiste, el correo saliente quedo configurado correctamente.`r`n"

    $cliente = New-Object System.Net.Mail.SmtpClient($servidorFinal, $puertoFinal)
    $cliente.EnableSsl = $true
    $cliente.UseDefaultCredentials = $false
    $cliente.DeliveryMethod = [System.Net.Mail.SmtpDeliveryMethod]::Network
    $cliente.Timeout = 15000
    $cliente.Credentials = New-Object System.Net.NetworkCredential($usuarioFinal, $clave)

    Write-Host ''
    Write-Host 'Enviando correo de prueba...' -ForegroundColor Cyan
    $cliente.Send($mensaje)
    Write-Host 'Correo de prueba enviado. Revisa la bandeja del remitente.' -ForegroundColor Green
} catch {
    $base = $_.Exception.GetBaseException()
    Write-Host ''
    Write-Host ('No se pudo enviar el correo de prueba: ' + $base.Message) -ForegroundColor Red
    if ($base.InnerException) {
        Write-Host ('Detalle: ' + $base.InnerException.Message) -ForegroundColor Red
    }
    if ($base -is [System.Net.Mail.SmtpException]) {
        Write-Host ('Estado SMTP: ' + [int]$base.StatusCode + ' (' + $base.StatusCode + ')') -ForegroundColor Red
    }
    Write-Host 'No se guardo ningun archivo. Revisa los datos y vuelve a intentarlo.' -ForegroundColor Yellow
    exit 1
} finally {
    if ($null -ne $mensaje) { $mensaje.Dispose() }
    if ($null -ne $cliente) { $cliente.Dispose() }
}

$carpetaDatos = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\LavaFacil.Web\Data'))
if (-not [System.IO.Directory]::Exists($carpetaDatos)) {
    [void][System.IO.Directory]::CreateDirectory($carpetaDatos)
}

$configuracion = [ordered]@{
    host = $servidorFinal
    port = [int]$puertoFinal
    usuario = $usuarioFinal
    clave = $clave
    remitente = $remitenteFinal
    nombre = $nombreFinal
    ssl = $true
}

try {
    $json = $configuracion | ConvertTo-Json -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $blob = [System.Security.Cryptography.ProtectedData]::Protect($bytes, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
    $rutaArchivo = Join-Path $carpetaDatos 'correo.dpapi'
    [System.IO.File]::WriteAllBytes($rutaArchivo, $blob)
} finally {
    $clave = $null
    $configuracion = $null
    $json = $null
    $bytes = $null
    $blob = $null
}

Write-Host ''
Write-Host ('Configuracion cifrada guardada en: ' + $rutaArchivo) -ForegroundColor Green
Write-Host 'Reinicia la aplicacion LavaFacil para que use el correo saliente.' -ForegroundColor Yellow
