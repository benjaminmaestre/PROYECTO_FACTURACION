#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import csv
import smtplib
import os
import re
from email.message import EmailMessage

# Configuración del servidor SMTP
SMTP_SERVER = "smtp.gmail.com"
SMTP_PORT = 587
SMTP_USER = "proyectscript@gmail.com"
SMTP_PASS = "puvkvnhnpriofsqg"

# Validación básica de email
def is_valid_email(email):
    pattern = r'^[\w\.-]+@[\w\.-]+\.\w+$'
    return re.match(pattern, email)

# Logs
log_envios = "log_envios.csv"

# Leer pendientes
if not os.path.exists("pendientes_envio.csv"):
    print("No existe pendientes_envio.csv")
    exit(1)

pendientes = []
with open("pendientes_envio.csv", newline='', encoding='utf-8') as csvfile:
    reader = csv.reader(csvfile)
    for row in reader:
        pendientes.append(row)

exitosos = []

# Enviar correos
with open(log_envios, 'a', encoding='utf-8', newline='') as logfile:
    log_writer = csv.writer(logfile)
    for factura, correo in pendientes:
        status = "fallido"
        if is_valid_email(correo):
            try:
                msg = EmailMessage()
                msg['Subject'] = "Factura Mercado IRSI"
                msg['From'] = SMTP_USER
                msg['To'] = correo
                msg.set_content("Adjuntamos su factura electrónica. ¡Gracias por su compra!")

                with open(factura, 'rb') as f:
                    file_data = f.read()
                    file_name = os.path.basename(factura)
                msg.add_attachment(file_data, maintype='application', subtype='pdf', filename=file_name)

                with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
                    server.starttls()
                    server.login(SMTP_USER, SMTP_PASS)
                    server.send_message(msg)

                status = "exitoso"
                exitosos.append([factura, correo])
            except Exception as e:
                print(f"Error enviando a {correo}: {e}")

        log_writer.writerow([factura, correo, status])

# Eliminar exitosos de pendientes_envio.csv
pendientes_restantes = [p for p in pendientes if p not in exitosos]
with open("pendientes_envio.csv", 'w', encoding='utf-8', newline='') as csvfile:
    writer = csv.writer(csvfile)
    writer.writerows(pendientes_restantes)

print("✔ Proceso de envío completado. Revisa log_envios.csv")
