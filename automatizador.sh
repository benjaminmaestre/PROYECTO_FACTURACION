#!/bin/bash

echo "⚙️ Generando nuevas compras..."
python generador_compras.py

# Encuentra el último CSV generado (el más nuevo)
CSV_FILE=$(ls -t compras/*.csv | grep -v log | head -1)

echo "📝 Usando archivo CSV: $CSV_FILE"
echo "🖨 Generando facturas..."
./generador_facturas.sh "$CSV_FILE"

echo "✉ Enviando facturas por correo..."
python enviador.py

echo "✅ Proceso automatizado completado."
