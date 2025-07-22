#!/bin/bash

# Función mejorada para escapar caracteres LaTeX
escape_latex() {
    local text="$1"
    # Escapar caracteres especiales de LaTeX en el orden correcto
    text=$(printf '%s' "$text" | sed \
        -e 's/\\/\\textbackslash{}/g' \
        -e 's/#/\\#/g' \
        -e 's/\$/\\$/g' \
        -e 's/%/\\%/g' \
        -e 's/&/\\&/g' \
        -e 's/_/\\_/g' \
        -e 's/\^/\\textasciicircum{}/g' \
        -e 's/~/\\textasciitilde{}/g' \
        -e 's/{/\\{/g' \
        -e 's/}/\\}/g')
    echo "$text"
}

# Sustitución segura campo a campo
safe_substitute() {
    local file="$1"
    local placeholder="$2"
    local value="$3"
    # Escapar para sed (doble escape porque ya viene escapado de LaTeX)
    local escaped_value=$(printf '%s\n' "$value" | sed 's/[\/&]/\\&/g')
    sed -i "s/{${placeholder}}/${escaped_value}/g" "$file"
}

INPUT_CSV=$1
if [ -z "$INPUT_CSV" ]; then
    echo "❌ Error: Debes proporcionar un archivo CSV"
    echo "Uso: $0 archivo.csv"
    exit 1
fi

if [ ! -f "$INPUT_CSV" ]; then
    echo "❌ Error: El archivo $INPUT_CSV no existe"
    exit 1
fi

if [ ! -f "plantilla_factura_IRSI.tex" ]; then
    echo "❌ Error: No se encuentra la plantilla plantilla_factura_IRSI.tex"
    exit 1
fi

# Verificar que pdflatex esté disponible
if ! command -v pdflatex &> /dev/null; then
    echo "❌ Error: pdflatex no está instalado o no está en el PATH"
    echo "💡 Instala MiKTeX o TeX Live para compilar documentos LaTeX"
    exit 1
fi

# Crear directorios
mkdir -p facturas
> log_diario.log
> pendientes_envio.csv

echo "📋 Procesando archivo: $INPUT_CSV"
echo "📁 Plantilla: plantilla_factura_IRSI.tex"
echo "🎯 Directorio de salida: facturas/"
echo

# Contar líneas para mostrar progreso
total_lines=$(tail -n +2 "$INPUT_CSV" | wc -l)
current_line=0

# Procesar CSV línea por línea
tail -n +2 "$INPUT_CSV" | while IFS=';' read -r id_transaccion fecha_emision nombre correo telefono direccion ciudad cantidad monto pago estado_pago ip timestamp observaciones
do
    current_line=$((current_line + 1))
    echo "[$current_line/$total_lines] Procesando factura: $id_transaccion"
    
    TEX_FILE="facturas/factura_${id_transaccion}.tex"
    PDF_FILE="facturas/factura_${id_transaccion}.pdf"
    
    # Copiar plantilla
    cp plantilla_factura_IRSI.tex "$TEX_FILE"
    
    # Escapar campos que contienen datos del usuario
    nombre_escaped=$(escape_latex "$nombre")
    correo_escaped=$(escape_latex "$correo")
    telefono_escaped=$(escape_latex "$telefono")
    direccion_escaped=$(escape_latex "$direccion")
    ciudad_escaped=$(escape_latex "$ciudad")
    observaciones_escaped=$(escape_latex "$observaciones")
    
    # Sustituir todos los campos
    safe_substitute "$TEX_FILE" "id_transaccion" "$id_transaccion"
    safe_substitute "$TEX_FILE" "fecha_emision" "$fecha_emision"
    safe_substitute "$TEX_FILE" "nombre" "$nombre_escaped"
    safe_substitute "$TEX_FILE" "correo" "$correo_escaped"
    safe_substitute "$TEX_FILE" "telefono" "$telefono_escaped"
    safe_substitute "$TEX_FILE" "direccion" "$direccion_escaped"
    safe_substitute "$TEX_FILE" "ciudad" "$ciudad_escaped"
    safe_substitute "$TEX_FILE" "cantidad" "$cantidad"
    safe_substitute "$TEX_FILE" "monto" "$monto"
    safe_substitute "$TEX_FILE" "pago" "$pago"
    safe_substitute "$TEX_FILE" "estado_pago" "$estado_pago"
    safe_substitute "$TEX_FILE" "ip" "$ip"
    safe_substitute "$TEX_FILE" "timestamp" "$timestamp"
    safe_substitute "$TEX_FILE" "observaciones" "$observaciones_escaped"
    
    # Compilar LaTeX con manejo mejorado de errores
    if pdflatex -interaction=nonstopmode -output-directory=facturas "$TEX_FILE" > "facturas/compile_${id_transaccion}.log" 2>&1; then
        if [ -f "$PDF_FILE" ]; then
            echo "Factura $id_transaccion: generada exitosamente" >> log_diario.log
            echo "$PDF_FILE,$correo" >> pendientes_envio.csv
            echo "  ✅ Compilada exitosamente"
            
            # Limpiar archivos auxiliares de LaTeX
            rm -f "facturas/factura_${id_transaccion}.aux" \
                  "facturas/factura_${id_transaccion}.log" \
                  "facturas/factura_${id_transaccion}.tex"
        else
            echo "Factura $id_transaccion: ERROR - PDF no generado" >> log_diario.log
            echo "  ❌ PDF no fue generado"
        fi
    else
        echo "Factura $id_transaccion: ERROR al compilar" >> log_diario.log
        echo "  ❌ Error en compilación LaTeX"
        echo "     📄 Ver detalles en: facturas/compile_${id_transaccion}.log"
        
        # Mostrar primeras líneas del error para debug
        if [ -f "facturas/compile_${id_transaccion}.log" ]; then
            echo "     🔍 Primeras líneas del error:"
            head -10 "facturas/compile_${id_transaccion}.log" | sed 's/^/        /'
        fi
    fi
done

# Resumen final
echo
echo "="*60
echo "📊 RESUMEN DE GENERACIÓN"
echo "="*60

if [ -f log_diario.log ]; then
    total_facturas=$(wc -l < log_diario.log)
    exitosas=$(grep -c "generada exitosamente" log_diario.log)
    errores=$(grep -c "ERROR" log_diario.log)
    
    echo "📄 Total procesadas: $total_facturas"
    echo "✅ Exitosas: $exitosas"
    echo "❌ Con errores: $errores"
fi

if [ -f pendientes_envio.csv ]; then
    pendientes=$(wc -l < pendientes_envio.csv)
    echo "📧 Pendientes de envío: $pendientes"
fi

echo "="*60
echo "✔ Proceso terminado."
echo "📋 Revisa: log_diario.log"
echo "📧 Facturas listas para envío: pendientes_envio.csv"