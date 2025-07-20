#!/bin/bash

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para logging con timestamp
log_message() {
    echo -e "${2:-$NC}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Función para verificar el resultado del comando anterior
check_result() {
    if [ $? -eq 0 ]; then
        log_message "✔ $1 completado exitosamente" "$GREEN"
    else
        log_message "❌ Error en: $1" "$RED"
        echo "Revisa los logs para más detalles."
    fi
}

log_message "🚀 Iniciando proceso automatizado de facturación..." "$BLUE"

# 1. Generar nuevas compras
log_message "⚙️ Generando nuevas compras..." "$YELLOW"
python generador_compras.py
check_result "Generación de compras"

# 2. Buscar el último CSV generado
CSV_FILE=$(ls -t compras/*.csv 2>/dev/null | grep -v log | head -1)

if [ -z "$CSV_FILE" ]; then
    log_message "❌ No se encontró ningún archivo CSV en la carpeta compras/" "$RED"
    exit 1
fi

log_message "📝 Usando archivo CSV: $CSV_FILE" "$BLUE"

# 3. Generar facturas
log_message "🖨 Generando facturas..." "$YELLOW"
./generador_facturas.sh "$CSV_FILE"
check_result "Generación de facturas"

# 4. Enviar facturas por correo
log_message "✉ Enviando facturas por correo..." "$YELLOW"
python enviador.py
check_result "Envío de correos"

# 5. Gestionar usuarios temporales
log_message "👤 Gestionando usuarios temporales..." "$YELLOW"

# Verificar si existe el archivo empleados.csv
if [ ! -f "empleados.csv" ]; then
    log_message "⚠️ No se encontró empleados.csv, saltando creación de usuarios" "$YELLOW"
else
    # Intentar ejecutar con permisos elevados
    log_message "🔐 Ejecutando script de usuarios (requiere permisos de administrador)..." "$YELLOW"
    
    # Método 1: Intentar con Start-Process y RunAs
    powershell.exe -Command "Start-Process PowerShell -Verb RunAs -ArgumentList '-File usuarios.ps1 -WindowStyle Hidden' -Wait" 2>/dev/null
    
    if [ $? -ne 0 ]; then
        # Método 2: Ejecutar normalmente y capturar el error
        log_message "⚠️ No se pudieron elevar permisos automáticamente. Ejecutando script normal..." "$YELLOW"
        powershell.exe -File usuarios.ps1
        
        if [ $? -ne 0 ]; then
            log_message "❌ Falló la creación de usuarios por falta de permisos" "$RED"
            log_message "💡 Para crear usuarios, ejecuta manualmente:" "$YELLOW"
            log_message "   1. Abre PowerShell como administrador" "$YELLOW"
            log_message "   2. Navega a: cd \"$(pwd)\"" "$YELLOW"
            log_message "   3. Ejecuta: .\\usuarios.ps1" "$YELLOW"
        else
            check_result "Gestión de usuarios"
        fi
    else
        check_result "Gestión de usuarios (con permisos elevados)"
    fi
fi

log_message "📊 Generando resumen de ejecución..." "$BLUE"

# Generar un resumen básico
echo ""
echo "═══════════════════════════════════════════════════════════════"
log_message "📋 RESUMEN DE EJECUCIÓN" "$BLUE"
echo "═══════════════════════════════════════════════════════════════"

# Contar facturas generadas
if [ -d "facturas" ]; then
    FACTURAS_COUNT=$(find facturas -name "*.pdf" -newer "$CSV_FILE" 2>/dev/null | wc -l)
    log_message "📄 Facturas generadas: $FACTURAS_COUNT" "$GREEN"
fi

# Verificar logs de envío
if [ -f "log_envios.csv" ]; then
    ENVIOS_COUNT=$(tail -n +2 log_envios.csv 2>/dev/null | wc -l)
    log_message "✉️ Correos procesados: $ENVIOS_COUNT" "$GREEN"
fi

# Verificar usuarios creados
if [ -f "usuarios_creados.log" ]; then
    USUARIOS_COUNT=$(wc -l < usuarios_creados.log 2>/dev/null)
    log_message "👤 Usuarios creados: $USUARIOS_COUNT" "$GREEN"
else
    log_message "👤 Usuarios creados: 0 (requiere permisos de administrador)" "$YELLOW"
fi

echo "═══════════════════════════════════════════════════════════════"
log_message "✅ Proceso automatizado completado" "$GREEN"
echo "═══════════════════════════════════════════════════════════════"

# Mostrar archivos importantes generados
echo ""
log_message "📁 Archivos importantes generados:" "$BLUE"
[ -f "log_diario.log" ] && echo "   • log_diario.log (registro de facturas)"
[ -f "pendientes_envio.csv" ] && echo "   • pendientes_envio.csv (facturas pendientes)"
[ -f "log_envios.csv" ] && echo "   • log_envios.csv (registro de envíos)"
[ -f "usuarios_creados.log" ] && echo "   • usuarios_creados.log (credenciales de usuarios)"
[ -f "usuarios_errores.log" ] && echo "   • usuarios_errores.log (errores en creación de usuarios)"

echo ""
log_message "🔒 RECORDATORIO DE SEGURIDAD:" "$RED"
log_message "   • Revisa y elimina usuarios_creados.log después de usar las credenciales" "$YELLOW"
log_message "   • Cambia las contraseñas temporales en el primer acceso" "$YELLOW"