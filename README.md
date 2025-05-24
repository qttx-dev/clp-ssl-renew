# 🔒 CloudPanel AutoSSL – Let's Encrypt Automation Script

![Bash Script](https://img.shields.io/badge/script-bash-green?logo=gnu-bash)
![Let's Encrypt](https://img.shields.io/badge/ssl-letsencrypt-blue?logo=letsencrypt)
![CloudPanel](https://img.shields.io/badge/cloudpanel-compatible-yellow?logo=linux)
![License: MIT](https://img.shields.io/badge/license-MIT-blue)

Ein automatisiertes Shell-Skript, das deine Let's Encrypt-Zertifikate erneuert, ins richtige CloudPanel-Verzeichnis kopiert und mit `clpctl` importiert – vollständig automatisiert per Cronjob.

---

## ✨ Features

- 🔍 Erkennt Domains anhand der vorhandenen `.key`-Dateien
- 🔐 Prüft das Ablaufdatum mit `openssl`
- ♻️ Erneuert ablaufende Zertifikate über `certbot` im Webroot-Modus
- 📂 Kopiert `fullchain.pem` und `privkey.pem` ins Zielverzeichnis
- 📥 Importiert mit `clpctl site:install:certificate`
- 📜 Loggt alle Schritte unter `/var/log/cloudpanel-certificate-auto.log`
- 🚫 Ignoriert `custom-domain` automatisch
- ✅ Kompatibel mit Pfadstruktur wie `/home/<benutzer>/htdocs/<domain>`

---

## 🧰 Voraussetzungen

- CloudPanel (getestet ab Version 2.x)
- Certbot installiert (`sudo apt install certbot`)
- Root-Zugriff
- Domains unter `/home/<benutzer>/htdocs/<domain>`
- Zertifikate unter `/etc/nginx/ssl-certificates`

---

## 🚀 Installation

### ✅ Option 1: Mit Git

```bash
git clone https://github.com/qttx-dev/clp-ssl-renew.git
cd clp-ssl-renew
sudo cp clp-ssl-renew.sh /usr/local/bin/clp-ssl-renew.sh
sudo chmod +x /usr/local/bin/clp-ssl-renew.sh
```

### 🌐 Option 2: Direkt herunterladen

```bash
sudo wget https://raw.githubusercontent.com/qttx-dev/clp-ssl-renew/refs/heads/main/clp-ssl-renew.sh -O /usr/local/bin/clp-ssl-renew.sh
sudo chmod +x /usr/local/bin/clp-ssl-renew.sh
```

---

## ⚙️ Konfiguration

### 🔧 E-Mail-Adresse für Certbot setzen

Öffne die Datei `clp-ssl-renew.sh` in einem Editor deiner Wahl und passe die folgende Zeile an:

```bash
CERTBOT_EMAIL="deine-email@domain.de"
```

Diese Adresse wird beim Kontakt mit Let's Encrypt verwendet.

---

### ⏳ Erneuerungszeitraum konfigurieren

Das Skript erneuert Zertifikate standardmäßig, wenn sie in ≤ 14 Tagen ablaufen. Ändere dies mit:

```bash
WARN_DAYS=14
```

---

## ⏰ Täglichen Cronjob einrichten

Um das Skript automatisch jeden Tag auszuführen:

```bash
sudo crontab -e
```

Füge folgende Zeile hinzu (Erneuerung täglich um 3:00 Uhr morgens):

```cron
0 3 * * * /usr/local/bin/clp-ssl-renew.sh
```

---

## 📄 Was macht das Skript?

1. Erkennt `.key`-Dateien in `/etc/nginx/ssl-certificates`
2. Prüft zugehörige `.crt`-Zertifikate mit `openssl`
3. Nutzt `certbot` zur Erneuerung via Webroot:
   - Webroot wird automatisch auf `/home/<benutzer>/htdocs/<domain>` gemappt
4. Kopiert `fullchain.pem` → `.crt`, `privkey.pem` → `.key`
5. Importiert Zertifikat via `clpctl`
6. Schreibt alle Aktionen ins Logfile

---

## 📁 Verzeichnisstruktur

Beispiel: `muster.de`

```text
Webroot:      /home/muster/htdocs/muster.de
Zertifikat:   /etc/nginx/ssl-certificates/muster.de.crt
Private Key:  /etc/nginx/ssl-certificates/muster.de.key
```

---

## 📝 Beispielausgabe

```text
2025-05-24 03:00:01 ===== Start Zertifikatsprüfung =====
2025-05-24 03:00:01 🔁 Zertifikat für muster.de läuft in 7 Tagen ab – erneuere.
2025-05-24 03:00:03 ✅ Zertifikat erfolgreich kopiert und installiert: muster.de
2025-05-24 03:00:04 ------------------------
2025-05-24 03:00:04 ✅ Alle Domains überprüft.
```

---

## 🧾 Hinweise

- Port 80 muss erreichbar sein (für Certbot Webroot-Modus)
- `custom-domain` wird automatisch ignoriert
- Ungültige oder fehlende Webroots werden protokolliert
- Testlauf manuell starten:

```bash
sudo /usr/local/bin/clp-ssl-renew.sh
```

---

## 📝 Lizenz

MIT License – du darfst das Skript frei verwenden, anpassen und weitergeben.

---

## 👨‍💻 Autor

Erstellt von [qttx-dev] [https://github.com/dein-benutzer]  
Pull Requests, Issues und ⭐ sind willkommen!
