# usuarios.ps1
# Script para gestión completa de usuarios: ver, eliminar, crear y verificar

# Configurar la codificación de salida para PowerShell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Verificar si se ejecuta con permisos de administrador
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Write-Host "❌ ERROR: Se requieren permisos de administrador." -ForegroundColor Red
    exit 1
}

Write-Host "🔧 GESTIÓN COMPLETA DE USUARIOS" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# 1. Ver usuarios existentes
Write-Host "1️⃣ USUARIOS EXISTENTES:" -ForegroundColor Yellow
$usuariosExistentes = Get-LocalUser | Where-Object { $_.Name -match "juan.perez|maria.gomez|carlos.rodriguez|ana.martinez|luis.sanchez|pedro.garcia|sofia.lopez|miguel.torres|carmen.ruiz|roberto.silva" }
if ($usuariosExistentes) {
    $usuariosExistentes | Format-Table Name, FullName, Enabled -AutoSize
} else {
    Write-Host "   No se encontraron usuarios del proyecto" -ForegroundColor Gray
}
Write-Host ""

# 2. Ver contraseñas de usuarios ya creados
Write-Host "2️⃣ CONTRASEÑAS DE USUARIOS CREADOS ANTERIORMENTE:" -ForegroundColor Yellow
if (Test-Path "usuarios_creados.log") {
    Write-Host "📄 Contenido del log anterior:" -ForegroundColor Cyan
    Get-Content "usuarios_creados.log" -Encoding UTF8 | ForEach-Object {
        if ($_ -notmatch "^Timestamp,") {
            Write-Host "   $_" -ForegroundColor White
        }
    }
} else {
    Write-Host "   No hay log de usuarios creados anteriormente" -ForegroundColor Gray
}
Write-Host ""

# 3. Preguntar si eliminar usuarios existentes
if ($usuariosExistentes) {
    Write-Host "3️⃣ ¿ELIMINAR USUARIOS EXISTENTES?" -ForegroundColor Yellow
    $respuesta = Read-Host "¿Deseas eliminar los usuarios existentes? (s/n)"
    
    if ($respuesta -eq "s" -or $respuesta -eq "S") {
        Write-Host "🗑️ Eliminando usuarios existentes..." -ForegroundColor Red
        $usuariosExistentes | ForEach-Object {
            try {
                Remove-LocalUser -Name $_.Name
                Write-Host "   ✅ Usuario $($_.Name) eliminado" -ForegroundColor Green
            } catch {
                Write-Host "   ❌ Error eliminando $($_.Name): $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "   Usuarios existentes conservados" -ForegroundColor Gray
    }
    Write-Host ""
}

# 4. Verificar archivo CSV
Write-Host "4️⃣ VERIFICANDO ARCHIVO CSV:" -ForegroundColor Yellow
if (-not (Test-Path "empleados.csv")) {
    Write-Host "❌ No se encontró empleados.csv, creando archivo de ejemplo..." -ForegroundColor Red
    @"
Nombre,Correo
Juan Pérez,juan.perez@empresa.com
María Gómez,maria.gomez@empresa.com
Carlos Rodriguez,carlos.rodriguez@empresa.com
Ana Martinez,ana.martinez@empresa.com
Luis Fernando Sánchez,luis.sanchez@empresa.com
Pedro García,pedro.garcia@empresa.com
Sofia López,sofia.lopez@empresa.com
Miguel Torres,miguel.torres@empresa.com
Carmen Ruiz,carmen.ruiz@empresa.com
Roberto Silva,roberto.silva@empresa.com
"@ | Out-File -FilePath "empleados.csv" -Encoding UTF8
    Write-Host "✅ Archivo empleados.csv creado con usuarios de ejemplo" -ForegroundColor Green
}

# Mostrar contenido del CSV
Write-Host "📄 Contenido del archivo empleados.csv:" -ForegroundColor Cyan
Import-Csv "empleados.csv" -Encoding UTF8 | Format-Table -AutoSize
Write-Host ""

# 5. Crear usuarios
Write-Host "5️⃣ CREANDO USUARIOS:" -ForegroundColor Yellow
Write-Host "🔐 Iniciando creación de usuarios..." -ForegroundColor Green

# Limpiar logs anteriores
if (Test-Path "usuarios_creados.log") {
    Remove-Item "usuarios_creados.log"
}
if (Test-Path "usuarios_errores.log") {
    Remove-Item "usuarios_errores.log"
}

$successCount = 0
$errorCount = 0
$skippedCount = 0
$emptyDataCount = 0

# Crear encabezados en el archivo de log
"Timestamp,Nombre Completo,Correo,Usuario,Contraseña" | Out-File -FilePath "usuarios_creados.log" -Encoding UTF8

Import-Csv "empleados.csv" -Encoding UTF8 | ForEach-Object {
    $NombreCompleto = $_.Nombre
    $Correo = $_.Correo
    $Username = $Correo.Split('@')[0]

    # Validar datos
    if ([string]::IsNullOrEmpty($NombreCompleto) -or [string]::IsNullOrEmpty($Correo)) {
        Write-Host "   ⚠️  Saltando registro con datos vacíos" -ForegroundColor Yellow
        $emptyDataCount++
        return
    }

    # Generar contraseña segura
    $Chars = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#$%&*'.ToCharArray()
    $PasswordPlain = ""
    for ($i = 1; $i -le 12; $i++) {
        $PasswordPlain += Get-Random -InputObject $Chars
    }
    $Password = ConvertTo-SecureString $PasswordPlain -AsPlainText -Force

    try {
        # Verificar si ya existe
        if (Get-LocalUser -Name $Username -ErrorAction SilentlyContinue) {
            Write-Host "   ⚠️  Usuario $Username ya existe, saltando..." -ForegroundColor Yellow
            $skippedCount++
            return
        }

        # Crear descripción corta
        $shortDate = Get-Date -Format 'yyyy-MM-dd'
        $description = "Usuario temporal - $shortDate"

        # Crear usuario
        New-LocalUser -Name $Username -FullName $NombreCompleto -Password $Password -Description $description

        # Detectar el nombre correcto del grupo Users/Usuarios
        $UsersGroup = $null
        try {
            # Intentar primero "Users" (inglés)
            $UsersGroup = Get-LocalGroup -Name "Users" -ErrorAction SilentlyContinue
            if (-not $UsersGroup) {
                # Intentar "Usuarios" (español)
                $UsersGroup = Get-LocalGroup -Name "Usuarios" -ErrorAction SilentlyContinue
            }
            if (-not $UsersGroup) {
                # Buscar por SID del grupo Users (funciona en cualquier idioma)
                $UsersGroup = Get-LocalGroup | Where-Object { $_.SID -eq "S-1-5-32-545" }
            }
            
            if ($UsersGroup) {
                Add-LocalGroupMember -Group $UsersGroup.Name -Member $Username
            } else {
                Write-Host "   ⚠️  No se pudo encontrar el grupo Users/Usuarios para $Username" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "   ⚠️  Error agregando $Username al grupo: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # Log
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "$timestamp,$NombreCompleto,$Correo,$Username,$PasswordPlain" | Out-File -Append -FilePath "usuarios_creados.log" -Encoding UTF8

        Write-Host "   ✅ Usuario $Username creado exitosamente" -ForegroundColor Green
        $successCount++

    } catch {
        Write-Host "   ❌ Error creando usuario $Username`: $($_.Exception.Message)" -ForegroundColor Red
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        if (-not (Test-Path "usuarios_errores.log")) {
            "Timestamp,Tipo,Nombre,Correo,Usuario,Error" | Out-File -FilePath "usuarios_errores.log" -Encoding UTF8
        }
        "$timestamp,ERROR,$NombreCompleto,$Correo,$Username,$($_.Exception.Message)" | Out-File -Append -FilePath "usuarios_errores.log" -Encoding UTF8
        $errorCount++
    }
}

Write-Host ""

# 6. Mostrar resumen final mejorado
Write-Host "6️⃣ RESUMEN FINAL:" -ForegroundColor Yellow
Write-Host "   ✅ Usuarios creados exitosamente: $successCount" -ForegroundColor Green

if ($skippedCount -gt 0) {
    Write-Host "   ℹ️  Usuarios ya existentes (saltados): $skippedCount" -ForegroundColor Cyan
}

if ($emptyDataCount -gt 0) {
    Write-Host "   ⚠️  Registros con datos vacíos: $emptyDataCount" -ForegroundColor Yellow
}

if ($errorCount -gt 0) {
    Write-Host "   ❌ Errores reales encontrados: $errorCount" -ForegroundColor Red
}

if ($successCount -eq 0 -and $skippedCount -gt 0 -and $errorCount -eq 0) {
    Write-Host ""
    Write-Host "   📋 No se crearon usuarios nuevos - Todos ya existían" -ForegroundColor Cyan
}

if ($successCount -gt 0) {
    Write-Host ""
    Write-Host "📄 CREDENCIALES GENERADAS:" -ForegroundColor Cyan
    Get-Content "usuarios_creados.log" -Encoding UTF8 | ForEach-Object {
        if ($_ -notmatch "^Timestamp,") {
            $datos = $_ -split ","
            if ($datos.Count -ge 5) {
                Write-Host "   👤 Usuario: $($datos[3]) | 🔑 Contraseña: $($datos[4])" -ForegroundColor White
            }
        }
    }
}

Write-Host ""
Write-Host "7️⃣ VERIFICACIÓN FINAL:" -ForegroundColor Yellow
$usuariosFinales = Get-LocalUser | Where-Object { $_.Name -match "juan.perez|maria.gomez|carlos.rodriguez|ana.martinez|luis.sanchez|pedro.garcia|sofia.lopez|miguel.torres|carmen.ruiz|roberto.silva" }
if ($usuariosFinales) {
    Write-Host "📊 Usuarios activos en el sistema:" -ForegroundColor Cyan
    $usuariosFinales | Format-Table Name, FullName, Enabled -AutoSize
} else {
    Write-Host "   No hay usuarios del proyecto en el sistema" -ForegroundColor Gray
}

Write-Host ""
Write-Host "🔒 RECORDATORIOS DE SEGURIDAD:" -ForegroundColor Red
Write-Host "   • Cambia las contraseñas en el primer inicio de sesión" -ForegroundColor Yellow
Write-Host "   • Elimina usuarios_creados.log después de distribuir credenciales" -ForegroundColor Yellow
Write-Host "   • Los usuarios están en grupo 'Users' por seguridad" -ForegroundColor Yellow
Write-Host ""
Write-Host "✅ GESTIÓN COMPLETA FINALIZADA" -ForegroundColor Green