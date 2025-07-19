# usuarios.ps1

Import-Csv "empleados.csv" | ForEach-Object {
    $NombreCompleto = $_.Nombre
    $Correo = $_.Correo

    # Genera una contraseña aleatoria segura
    $Chars = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#$%&*'
    $PasswordPlain = -join ((1..12) | ForEach-Object { $Chars | Get-Random })
    $Password = ConvertTo-SecureString $PasswordPlain -AsPlainText -Force

    # Usa el correo como nombre de usuario local simplificado
    $Username = $Correo.Split('@')[0]

    # Crea el usuario local
    New-LocalUser -Name $Username -FullName $NombreCompleto -Password $Password -Description "Usuario temporal creado automáticamente"

    # Lo agrega al grupo Administradores
    Add-LocalGroupMember -Group "Administrators" -Member $Username

    # Escribe en el log
    "$NombreCompleto, $Correo, $Username, $PasswordPlain" | Out-File -Append usuarios_creados.log

    Write-Host "✔ Usuario $Username creado con contraseña temporal segura."
}
