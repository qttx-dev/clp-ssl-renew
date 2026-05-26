# 🔒 CloudPanel AutoSSL – Let's Encrypt Automation Script

![Bash Script](https://img.shields.io/badge/script-bash-green?logo=gnu-bash)
![Let's Encrypt](https://img.shields.io/badge/ssl-letsencrypt-blue?logo=letsencrypt)
![CloudPanel](https://img.shields.io/badge/cloudpanel-compatible-yellow?logo=linux)
![License: MIT](https://img.shields.io/badge/license-MIT-blue)

Ein automatisiertes Shell-Skript, das deine Let's Encrypt-Zertifikate erneuert, ins richtige CloudPanel-Verzeichnis kopiert und normale Website-Zertifikate mit `clpctl` importiert – vollständig automatisiert per Cronjob.

Zusätzlich kann das Skript auch das SSL-Zertifikat der **CloudPanel-Oberfläche** erneuern, also die sogenannte **Custom Domain** des Panels.

---

## ✨ Features

- 🔍 Erkennt Website-Domains anhand der vorhandenen `.key`-Dateien
- 🔐 Prüft das Ablaufdatum vorhandener Zertifikate mit `openssl`
- ♻️ Erneuert ablaufende Website-Zertifikate über `certbot` im Webroot-Modus
- 📂 Erkennt Webroots automatisch unter `/home/<benutzer>/htdocs/<domain>`
- 📄 Kopiert `fullchain.pem` und `privkey.pem` ins CloudPanel-Zertifikatsverzeichnis
- 📥 Importiert normale Website-Zertifikate mit `clpctl site:install:certificate`
- 🖥️ Unterstützt zusätzlich das Zertifikat der CloudPanel-Oberfläche über `custom-domain.crt` und `custom-domain.key`
- 🧯 Erstellt Backups vorhandener Zertifikatsdateien vor dem Überschreiben
- 🧪 Prüft die nginx-Konfiguration mit `nginx -t`
- 🔄 Lädt nginx nach erfolgreicher Prüfung neu
- 📜 Loggt alle Schritte unter `/var/log/cloudpanel-certificate-auto.log`
- ✅ Kompatibel mit Pfadstruktur wie `/home/<benutzer>/htdocs/<domain>`

---

## 🧰 Voraussetzungen

- CloudPanel, getestet ab Version 2.x
- Root-Zugriff
- `certbot`
- `openssl`
- `nginx`
- CloudPanel-CLI `clpctl`
- Domains unter `/home/<benutzer>/htdocs/<domain>`
- Zertifikate unter `/etc/nginx/ssl-certificates`
- DNS-Einträge der Domains zeigen auf den Server
- Port 80 ist von außen erreichbar

Benötigte Pakete installieren:

```bash
sudo apt update
sudo apt install -y certbot openssl
```

`jq` wird nicht benötigt.

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

Öffne das Skript:

```bash
sudo nano /usr/local/bin/clp-ssl-renew.sh
```

---

### 🔧 E-Mail-Adresse für Certbot setzen

Passe diese Zeile an:

```bash
CERTBOT_EMAIL="deine-mail@domain.de"
```

Diese Adresse wird beim Kontakt mit Let's Encrypt verwendet.

Beispiel:

```bash
CERTBOT_EMAIL="admin@example.com"
```

---

### 🖥️ CloudPanel-Oberfläche konfigurieren

Wenn auch das Zertifikat der CloudPanel-Oberfläche erneuert werden soll, trage deine Panel-Domain ein:

```bash
PANEL_DOMAIN="panel.deinedomain.de"
```

Beispiel:

```bash
PANEL_DOMAIN="panel.example.com"
```

Die Domain muss per DNS auf diesen Server zeigen.

Die CloudPanel-Oberfläche nutzt normalerweise diese Zertifikatsdateien:

```text
/etc/nginx/ssl-certificates/custom-domain.crt
/etc/nginx/ssl-certificates/custom-domain.key
```

Diese Dateien werden vom Skript separat behandelt und nicht wie eine normale Website importiert.

---

### ⚠️ Standalone-Modus für die CloudPanel-Oberfläche

Für die CloudPanel-Oberfläche nutzt das Skript standardmäßig den Certbot-Standalone-Modus:

```bash
PANEL_USE_STANDALONE=true
```

Dabei wird nginx kurz gestoppt, damit Certbot Port 80 verwenden kann.

Danach wird nginx automatisch wieder gestartet.

Das ist nötig, weil die CloudPanel-Oberfläche normalerweise keinen normalen Webroot unter `/home/<benutzer>/htdocs/<domain>` hat.

---

### ⏳ Erneuerungszeitraum konfigurieren

Das Skript erneuert Zertifikate standardmäßig, wenn sie in 14 Tagen oder weniger ablaufen.

```bash
WARN_DAYS=14
```

Beispiel: Wenn du bereits 30 Tage vor Ablauf erneuern möchtest:

```bash
WARN_DAYS=30
```

---

## ⏰ Täglichen Cronjob einrichten

Um das Skript automatisch jeden Tag auszuführen:

```bash
sudo crontab -e
```

Füge folgende Zeile hinzu:

```cron
17 3 * * * /usr/local/bin/clp-ssl-renew.sh >/dev/null 2>&1
```

Damit läuft das Skript täglich um 03:17 Uhr.

---

## 📄 Was macht das Skript?

### 🌐 Normale CloudPanel-Websites

1. Erkennt `.key`-Dateien in `/etc/nginx/ssl-certificates`
2. Ermittelt daraus den Domainnamen
3. Sucht den passenden Webroot unter `/home/<benutzer>/htdocs/<domain>`
4. Prüft das zugehörige `.crt`-Zertifikat mit `openssl`
5. Erneuert das Zertifikat bei Bedarf mit `certbot --webroot`
6. Kopiert `fullchain.pem` nach `.crt`
7. Kopiert `privkey.pem` nach `.key`
8. Importiert das Zertifikat mit `clpctl site:install:certificate`
9. Prüft nginx mit `nginx -t`
10. Lädt nginx neu

---

### 🖥️ CloudPanel-Oberfläche / Custom Domain

Die CloudPanel-Oberfläche verwendet normalerweise:

```text
/etc/nginx/ssl-certificates/custom-domain.crt
/etc/nginx/ssl-certificates/custom-domain.key
```

Diese Dateien gehören nicht zu einer normalen Website.

Deshalb macht das Skript hier etwas anderes:

1. Prüft `custom-domain.crt`
2. Nutzt die konfigurierte `PANEL_DOMAIN`
3. Erneuert das Zertifikat per `certbot --standalone`
4. Stoppt nginx dafür kurz
5. Startet nginx danach wieder
6. Kopiert das neue Zertifikat nach `custom-domain.crt`
7. Kopiert den neuen Private Key nach `custom-domain.key`
8. Prüft nginx mit `nginx -t`
9. Lädt nginx neu

Wichtig: Für die Panel-Domain wird **kein** `clpctl site:install:certificate` genutzt.

---

## 📁 Verzeichnisstruktur

Beispiel für eine normale Website:

```text
Domain:       muster.de
Webroot:      /home/muster/htdocs/muster.de
Zertifikat:   /etc/nginx/ssl-certificates/muster.de.crt
Private Key:  /etc/nginx/ssl-certificates/muster.de.key
```

Beispiel für die CloudPanel-Oberfläche:

```text
Panel-Domain: panel.muster.de
Zertifikat:   /etc/nginx/ssl-certificates/custom-domain.crt
Private Key:  /etc/nginx/ssl-certificates/custom-domain.key
```

---

## 📝 Beispielausgabe

```text
2026-05-26 03:17:01 ===== Start Zertifikatsprüfung =====
2026-05-26 03:17:01 🔁 Zertifikat für panel.muster.de läuft in 5 Tagen ab – erneuere.
2026-05-26 03:17:02 🔐 Erneuere CloudPanel-Oberflächen-Zertifikat für panel.muster.de.
2026-05-26 03:17:03 ℹ️  Nutze standalone-Modus. nginx wird kurz gestoppt.
2026-05-26 03:17:08 ✅ Certbot standalone für panel.muster.de erfolgreich.
2026-05-26 03:17:09 ✅ CloudPanel-Oberflächen-Zertifikat installiert und nginx neu geladen.
2026-05-26 03:17:09 ------------------------
2026-05-26 03:17:10 ✅ Zertifikat für muster.de ist noch 42 Tage gültig – überspringe.
2026-05-26 03:17:10 ✅ CloudPanel-Site-Import für muster.de erfolgreich.
2026-05-26 03:17:10 ✅ nginx erfolgreich neu geladen.
2026-05-26 03:17:10 🏁 Zertifikatsprüfung abgeschlossen.
```

---

## 🧪 Testlauf

Das Skript kann jederzeit manuell gestartet werden:

```bash
sudo /usr/local/bin/clp-ssl-renew.sh
```

Log ansehen:

```bash
sudo tail -n 100 /var/log/cloudpanel-certificate-auto.log
```

nginx prüfen:

```bash
sudo nginx -t
```

---

## 🧾 Hinweise

- Port 80 muss erreichbar sein.
- DNS muss korrekt auf den Server zeigen.
- Normale Websites werden per Webroot-Modus erneuert.
- Die CloudPanel-Oberfläche wird separat über `custom-domain.crt` und `custom-domain.key` behandelt.
- `custom-domain` wird nicht als normale Website verarbeitet.
- Für die CloudPanel-Oberfläche wird bei `PANEL_USE_STANDALONE=true` nginx kurz gestoppt.
- Ungültige oder fehlende Webroots werden protokolliert.
- Vor dem Überschreiben vorhandener Zertifikatsdateien werden Backups erstellt.
- Das Skript sollte als root ausgeführt werden.
- Das Skript ersetzt kein vollständiges Server-Backup.

---

## 🔎 Nützliche Prüf-Befehle

### DNS prüfen

```bash
dig +short muster.de
dig +short panel.muster.de
```

Die Ausgabe sollte die IP-Adresse deines Servers zeigen.

---

### Port 80 prüfen

```bash
sudo ss -tulpn | grep ':80'
```

---

### Zertifikat prüfen

```bash
openssl x509 -in /etc/nginx/ssl-certificates/muster.de.crt -noout -dates
```

Für die CloudPanel-Oberfläche:

```bash
openssl x509 -in /etc/nginx/ssl-certificates/custom-domain.crt -noout -dates
```

---

### Log prüfen

```bash
sudo tail -f /var/log/cloudpanel-certificate-auto.log
```

---

## 🛠️ Fehlerbehebung

### ❌ Webroot nicht gefunden

Wenn im Log steht:

```text
Webroot für muster.de nicht gefunden – überspringe.
```

prüfe, ob die Domain wirklich unter dieser Struktur existiert:

```text
/home/<benutzer>/htdocs/<domain>
```

Beispiel:

```text
/home/muster/htdocs/muster.de
```

---

### ❌ Certbot-Fehler bei einer Website

Prüfe zuerst DNS und Erreichbarkeit:

```bash
dig +short muster.de
curl -I http://muster.de
```

Außerdem muss Port 80 erreichbar sein.

---

### ❌ CloudPanel-Oberfläche wird nicht erneuert

Prüfe, ob `PANEL_DOMAIN` korrekt gesetzt ist:

```bash
grep PANEL_DOMAIN /usr/local/bin/clp-ssl-renew.sh
```

Prüfe außerdem, ob die Zertifikatsdateien existieren:

```bash
ls -lah /etc/nginx/ssl-certificates/custom-domain.*
```

---

### ❌ nginx startet nach der Erneuerung nicht

Prüfe die nginx-Konfiguration:

```bash
sudo nginx -t
```

Log ansehen:

```bash
sudo tail -n 100 /var/log/cloudpanel-certificate-auto.log
```

Falls nötig, kannst du eine automatisch angelegte Backup-Datei wiederherstellen.

Beispiel:

```bash
ls -lah /etc/nginx/ssl-certificates/custom-domain.*
```

Dann passende `.bak`-Datei zurückkopieren.

---

## 📝 Lizenz

MIT License – du darfst das Skript frei verwenden, anpassen und weitergeben.

---

## 👨‍💻 Autor

Erstellt von [qttx-dev](https://github.com/qttx-dev)

Pull Requests, Issues und ⭐ sind willkommen!
