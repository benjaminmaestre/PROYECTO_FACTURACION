#!/bin/bash

# Función para escapar caracteres LaTeX en los datos
escape_latex() {
    local text="$1"
    # Solo escapamos los realmente peligrosos
    text=$(printf '%s' "$text" | sed 's/#/\\#/g; s/\$/\\$/g; s/%/\\%/g; s/&/\\&/g; s/_/\\_/g')
    echo "$text"
}

# Sustitución segura campo a campo
safe_substitute() {
    local file="$1"
    local placeholder="$2"
    local value="$3"
    # Escapar para sed
    local escaped_value=$(printf '%s\n' "$value" | sed 's/[\/&]/\\&/g')
    sed -i "s/{${placeholder}}/${escaped_value}/g" "$file"
}

INPUT_CSV=$1
if [ -z "$INPUT_CSV" ]; then
    echo "Uso: $0 archivo.csv"
    exit 1
fi

mkdir -p facturas
> log_diario.log
> pendientes_envio.csv

echo "Procesando archivo: $INPUT_CSV"

tail -n +2 "$INPUT_CSV" | while IFS=';' read -r id_transaccion fecha_emision nombre correo telefono direccion ciudad cantidad monto pago estado_pago ip timestamp observaciones
do
    echo "Procesando factura: $id_transaccion"
    
    TEX_FILE="facturas/factura_${id_transaccion}.tex"
    PDF_FILE="facturas/factura_${id_transaccion}.pdf"
    
    cp plantilla_factura_IRSI.tex "$TEX_FILE"
    
    # Escapar campos peligrosos (solo datos)
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
    
    # Compilar LaTeX con log de cada factura
    if pdflatex -output-directory=facturas "$TEX_FILE" > "facturas/compile_${id_transaccion}.log" 2>&1; then
        echo "Factura $id_transaccion: generada exitosamente" >> log_diario.log
        echo "facturas/factura_${id_transaccion}.pdf,$correo" >> pendientes_envio.csv
        echo "✓ Factura $id_transaccion compilada exitosamente"
    else
        echo "Factura $id_transaccion: ERROR al compilar" >> log_diario.log
        echo "✗ Error compilando factura $id_transaccion"
        echo "Ver log en: facturas/compile_${id_transaccion}.log"
        head -20 "facturas/compile_${id_transaccion}.log"
    fi

    echo "---"
done

echo "✔ Proceso terminado. Revisa log_diario.log y pendientes_envio.csv"
