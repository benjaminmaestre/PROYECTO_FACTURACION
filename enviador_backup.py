#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Compatibilidad con Windows - cargar variables desde .env si no están en el sistema
def cargar_env():
    """Carga variables de entorno desde archivo .env si existe"""
    env_file = '.env'
    if os.path.exists(env_file):
        with open(env_file, 'r', encoding='utf-8') as f:
            for linea in f:
                linea = linea.strip()
                if linea and not linea.startswith('#'):
                    if '=' in linea:
                        clave, valor = linea.split('=', 1)
                        os.environ[clave.strip()] = valor.strip()

# Cargar variables de entorno al inicio
cargar_env()

import csv
import smtplib
import os
import re
import sys
from email.message import EmailMessage
from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase
from email.mime.text import MIMEText
from email import encoders
import mimetypes

# Configuración del servidor SMTP
SMTP_SERVER = "smtp.gmail.com"
SMTP_PORT = 587

# 🔐 SEGURIDAD: Leer credenciales de variables de entorno
EMAIL_USER = os.getenv('EMAIL_USER')
EMAIL_PASS = os.getenv('EMAIL_PASS')

def validar_credenciales():
    """Valida que las credenciales estén configuradas"""
    if not EMAIL_USER or not EMAIL_PASS:
        print("❌ ERROR: Credenciales no configuradas")
        print("📋 Configura las variables de entorno:")
        print("   export EMAIL_USER='proyectscript@gmail.com'")
        print("   export EMAIL_PASS='puvkvnhnpriofsqg'")
        print("\n💡 O crea un archivo .env con las credenciales")
        return False
    return True

def validar_email(email):
    """Valida formato de email"""
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return re.match(pattern, email) is not None

def crear_mensaje(destinatario, asunto, cuerpo, archivo_adjunto=None):
    """Crea el mensaje de email con adjunto opcional"""
    try:
        msg = MIMEMultipart()
        msg['From'] = EMAIL_USER
        msg['To'] = destinatario
        msg['Subject'] = asunto
        
        # Agregar cuerpo del mensaje
        msg.attach(MIMEText(cuerpo, 'plain', 'utf-8'))
        
        # Agregar adjunto si existe
        if archivo_adjunto and os.path.exists(archivo_adjunto):
            with open(archivo_adjunto, "rb") as adjunto:
                parte = MIMEBase('application', 'octet-stream')
                parte.set_payload(adjunto.read())
                
            encoders.encode_base64(parte)
            parte.add_header(
                'Content-Disposition',
                f'attachment; filename= {os.path.basename(archivo_adjunto)}'
            )
            msg.attach(parte)
            print(f"📎 Adjunto agregado: {os.path.basename(archivo_adjunto)}")
        
        return msg
        
    except Exception as e:
        print(f"❌ Error creando mensaje: {e}")
        return None

def enviar_email(destinatario, asunto, cuerpo, archivo_adjunto=None):
    """Envía un email con adjunto opcional"""
    
    # Validar email
    if not validar_email(destinatario):
        print(f"❌ Email inválido: {destinatario}")
        return False
    
    try:
        # Crear mensaje
        msg = crear_mensaje(destinatario, asunto, cuerpo, archivo_adjunto)
        if not msg:
            return False
        
        # Conectar al servidor SMTP
        print(f"🔗 Conectando a {SMTP_SERVER}:{SMTP_PORT}...")
        servidor = smtplib.SMTP(SMTP_SERVER, SMTP_PORT)
        servidor.starttls()
        
        # Autenticar
        print(f"🔐 Autenticando como {EMAIL_USER}...")
        servidor.login(EMAIL_USER, EMAIL_PASS)
        
        # Enviar mensaje
        print(f"📧 Enviando email a {destinatario}...")
        texto = msg.as_string()
        servidor.sendmail(EMAIL_USER, destinatario, texto)
        
        servidor.quit()
        print(f"✅ Email enviado exitosamente a {destinatario}")
        return True
        
    except smtplib.SMTPAuthenticationError:
        print("❌ Error de autenticación SMTP")
        print("💡 Verifica que la App Password sea correcta")
        return False
    except smtplib.SMTPRecipientsRefused:
        print(f"❌ Destinatario rechazado: {destinatario}")
        return False
    except smtplib.SMTPServerDisconnected:
        print("❌ Conexión perdida con el servidor SMTP")
        return False
    except Exception as e:
        print(f"❌ Error enviando email: {e}")
        return False

def enviar_lote_emails(archivo_csv):
    """Envía emails en lote desde archivo CSV"""
    if not os.path.exists(archivo_csv):
        print(f"❌ Archivo no encontrado: {archivo_csv}")
        return False
    
    exitosos = 0
    fallidos = 0
    
    try:
        with open(archivo_csv, 'r', encoding='utf-8') as archivo:
            lector = csv.DictReader(archivo)
            
            for fila in lector:
                email = fila.get('email', '').strip()
                asunto = fila.get('asunto', 'Factura').strip()
                mensaje = fila.get('mensaje', '').strip()
                adjunto = fila.get('adjunto', '').strip()
                
                if not email:
                    print("⚠️ Fila sin email, saltando...")
                    continue
                
                # Verificar si el adjunto existe
                if adjunto and not os.path.exists(adjunto):
                    print(f"⚠️ Adjunto no encontrado: {adjunto}")
                    adjunto = None
                
                if enviar_email(email, asunto, mensaje, adjunto):
                    exitosos += 1
                else:
                    fallidos += 1
                
                print("-" * 50)
        
        print(f"\n📊 RESUMEN:")
        print(f"✅ Exitosos: {exitosos}")
        print(f"❌ Fallidos: {fallidos}")
        print(f"📧 Total: {exitosos + fallidos}")
        
        return True
        
    except Exception as e:
        print(f"❌ Error procesando archivo CSV: {e}")
        return False

def main():
    """Función principal"""
    print("📧 Sistema de Envío de Emails")
    print("=" * 40)
    
    # Validar credenciales
    if not validar_credenciales():
        sys.exit(1)
    
    # Verificar argumentos
    if len(sys.argv) < 2:
        print("📋 Uso:")
        print("  Envío individual:")
        print("    python enviador.py email@ejemplo.com 'Asunto' 'Mensaje' [archivo_adjunto]")
        print("  Envío en lote:")
        print("    python enviador.py archivo_emails.csv")
        sys.exit(1)
    
    # Determinar tipo de envío
    primer_argumento = sys.argv[1]
    
    if primer_argumento.endswith('.csv'):
        # Envío en lote
        print(f"📋 Procesando envío en lote: {primer_argumento}")
        enviar_lote_emails(primer_argumento)
    else:
        # Envío individual
        if len(sys.argv) < 4:
            print("❌ Faltan argumentos para envío individual")
            print("📋 Uso: python enviador.py email@ejemplo.com 'Asunto' 'Mensaje' [archivo_adjunto]")
            sys.exit(1)
        
        email = sys.argv[1]
        asunto = sys.argv[2]
        mensaje = sys.argv[3]
        adjunto = sys.argv[4] if len(sys.argv) > 4 else None
        
        print(f"📧 Enviando email individual a: {email}")
        enviar_email(email, asunto, mensaje, adjunto)

if __name__ == "__main__":
    main()