# 🔒 CloudPanel AutoSSL – Let's Encrypt Automation Script

![Bash Script](https://img.shields.io/badge/script-bash-green?logo=gnu-bash)
![Let's Encrypt](https://img.shields.io/badge/ssl-letsencrypt-blue?logo=letsencrypt)
![CloudPanel](https://img.shields.io/badge/cloudpanel-compatible-yellow?logo=linux)
![License: MIT](https://img.shields.io/badge/license-MIT-blue)

Ein automatisiertes Shell-Skript, das ablaufende Let's-Encrypt-Zertifikate auf CloudPanel-Servern erkennt und erneuert.

Normale CloudPanel-Websites werden nicht mehr direkt über `certbot --webroot` erneuert, sondern über den offiziellen CloudPanel-CLI-Befehl:

```bash
clpctl lets-encrypt:install:certificate --domainName=domain.de
```

Dadurch verhält sich das Skript deutlich näher an der CloudPanel-GUI und vermeidet typische Probleme mit Webroot, Reverse Proxy, HTTPS-Weiterleitungen oder IPv6-Challenges.

Zusätzlich kann das Skript optional auch das SSL-Zertifikat der **CloudPanel-Oberfläche** erneuern, also die sogenannte **Custom Domain** des Panels.

---

## ✨ Features

- 🔍 Erkennt Website-Domains anhand vorhandener `.key`-Dateien unter `/etc/nginx/ssl-certificates`
- 🔐 Prüft Ablaufdaten vorhandener Zertifikate mit `openssl`
- ♻️ Erneuert ablaufende Website-Zertifikate über CloudPanels eigenen CLI-Befehl
- 🧠 Nutzt für normale Sites `clpctl lets-encrypt:install:certificate`
- 🖥️ Unterstützt optional das Zertifikat der CloudPanel-Oberfläche über `custom-domain.crt` und `custom-domain.key`
- 🧯 Erstellt Backups vorhandener Zertifikatsdateien vor dem Überschreiben
- 🔒 Verhindert parallele Ausführungen per Lockfile
- 🧪 Prüft die nginx-Konfiguration mit `nginx -t`
- 🔄 Lädt nginx nach erfolgreicher Prüfung neu
- 📜 Loggt alle Schritte unter `/var/log/cloudpanel-certificate-auto.log`
- ✅ Kompatibel mit CloudPanel-Zertifikatsstruktur unter `/etc/nginx/ssl-certificates`

---

## 🧰 Voraussetzungen

- CloudPanel, getestet ab Version 2.x
- Root-Zugriff
- `clpctl`
- `openssl`
- `nginx`
- `flock`
- Optional: `certbot`, wenn auch die CloudPanel-Oberfläche / Custom Domain erneuert werden soll
- DNS-Einträge der Domains zeigen auf den Server
- Port 80 ist von außen erreichbar

Benötigte Pakete installieren:

```bash
sudo apt update
sudo apt install -y certbot openssl util-linux
```

Hinweis:

- `util-linux` enthält normalerweise `flock`
- `jq` wird nicht benötigt

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

### 🔧 Erneuerungszeitraum setzen

Das Skript erneuert Zertifikate standardmäßig, wenn sie in 14 Tagen oder weniger ablaufen.

```bash
WARN_DAYS=14
```

Beispiel: Wenn du bereits 30 Tage vor Ablauf erneuern möchtest:

```bash
WARN_DAYS=30
```

---

### 🌐 Normale CloudPanel-Websites

Für normale CloudPanel-Websites ist keine Certbot-Konfiguration nötig.

Das Skript nutzt automatisch:

```bash
clpctl lets-encrypt:install:certificate --domainName=domain.de
```

Das ist der wichtigste Unterschied zu älteren Versionen dieses Skripts.

Früher wurde direkt Certbot verwendet:

```bash
certbot certonly --webroot -w /home/<benutzer>/htdocs/<domain> -d <domain>
```

Das kann bei CloudPanel aber Probleme machen, zum Beispiel bei:

- Reverse-Proxy-Sites
- HTTP-zu-HTTPS-Weiterleitungen
- Docker-Backends
- IPv6-Challenges
- speziellen CloudPanel-vHost-Regeln

Deshalb übernimmt jetzt CloudPanel selbst die Ausstellung und Installation normaler Website-Zertifikate.

---

### 🖥️ CloudPanel-Oberfläche konfigurieren

Wenn auch das Zertifikat der CloudPanel-Oberfläche erneuert werden soll, trage deine Panel-Domain ein:

```bash
PANEL_DOMAIN="panel.deinedomain.de"
```

Beispiel:

```bash
PANEL_DOMAIN="server.example.com"
```

Wenn du die CloudPanel-Oberfläche nicht über dieses Skript erneuern möchtest, lasse die Variable leer:

```bash
PANEL_DOMAIN=""
```

Die CloudPanel-Oberfläche nutzt normalerweise diese Zertifikatsdateien:

```text
/etc/nginx/ssl-certificates/custom-domain.crt
/etc/nginx/ssl-certificates/custom-domain.key
```

Diese Dateien gehören nicht zu einer normalen CloudPanel-Website und werden deshalb separat behandelt.

---

### 📧 E-Mail-Adresse für Certbot setzen

Die E-Mail-Adresse wird nur für die CloudPanel-Oberfläche benötigt, wenn `PANEL_DOMAIN` gesetzt ist.

```bash
CERTBOT_EMAIL="deine-mail@domain.de"
```

Beispiel:

```bash
CERTBOT_EMAIL="admin@example.com"
```

Für normale CloudPanel-Websites wird diese E-Mail-Adresse vom Skript nicht verwendet, weil die Erneuerung über `clpctl` läuft.

---

### ⚠️ Standalone-Modus für die CloudPanel-Oberfläche

Für die CloudPanel-Oberfläche nutzt das Skript standardmäßig den Certbot-Standalone-Modus:

```bash
PANEL_USE_STANDALONE=true
```

Dabei wird nginx kurz gestoppt, damit Certbot Port 80 verwenden kann.

Danach wird nginx automatisch wieder gestartet.

Das ist nötig, weil die CloudPanel-Oberfläche normalerweise keinen normalen Website-Webroot unter `/home/<benutzer>/htdocs/<domain>` hat.

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

Das Skript besitzt zusätzlich ein Lockfile:

```text
/var/run/clp-ssl-renew.lock
```

Dadurch wird verhindert, dass mehrere Läufe parallel starten.

---

## 📄 Was macht das Skript?

### 🌐 Normale CloudPanel-Websites

1. Sucht `.key`-Dateien in `/etc/nginx/ssl-certificates`
2. Ermittelt daraus den Domainnamen
3. Überspringt `custom-domain`, weil diese separat behandelt wird
4. Prüft das zugehörige `.crt`-Zertifikat mit `openssl`
5. Erneuert das Zertifikat nur, wenn es bald abläuft oder ungültig ist
6. Nutzt dafür CloudPanels eigenen CLI-Befehl:

```bash
clpctl lets-encrypt:install:certificate --domainName=domain.de
```

7. Prüft anschließend nginx mit:

```bash
nginx -t
```

8. Lädt nginx neu

---

### 🖥️ CloudPanel-Oberfläche / Custom Domain

Die CloudPanel-Oberfläche verwendet normalerweise:

```text
/etc/nginx/ssl-certificates/custom-domain.crt
/etc/nginx/ssl-certificates/custom-domain.key
```

Diese Dateien gehören nicht zu einer normalen CloudPanel-Website.

Wenn `PANEL_DOMAIN` gesetzt ist, macht das Skript hier Folgendes:

1. Prüft `custom-domain.crt`
2. Nutzt die konfigurierte `PANEL_DOMAIN`
3. Stoppt nginx kurz
4. Erneuert das Zertifikat per:

```bash
certbot certonly --standalone -d panel.deinedomain.de
```

5. Startet nginx danach wieder
6. Kopiert das neue Zertifikat nach:

```text
/etc/nginx/ssl-certificates/custom-domain.crt
```

7. Kopiert den neuen Private Key nach:

```text
/etc/nginx/ssl-certificates/custom-domain.key
```

8. Prüft nginx mit `nginx -t`
9. Lädt nginx neu

Wichtig:

Für die Panel-Domain wird **kein** `clpctl site:install:certificate` genutzt.

---

## 📁 Verzeichnisstruktur

Beispiel für eine normale Website:

```text
Domain:       muster.de
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
2026-05-26 03:17:01 ℹ️  PANEL_DOMAIN ist leer – CloudPanel-Oberfläche wird übersprungen.
2026-05-26 03:17:01 ------------------------
2026-05-26 03:17:02 ✅ Zertifikat für example.com ist noch 42 Tage gültig – überspringe.
2026-05-26 03:17:02 ------------------------
2026-05-26 03:17:03 🔁 Zertifikat für test.example.com läuft in 5 Tagen ab – erneuere.
2026-05-26 03:17:03 🌐 Erneuere Site-Zertifikat für test.example.com über CloudPanel.
2026-05-26 03:17:08 ✅ CloudPanel hat das Zertifikat für test.example.com erfolgreich erneuert und installiert.
2026-05-26 03:17:08 ✅ Zertifikat für test.example.com ist nach CloudPanel-Erneuerung vorhanden und gültig lesbar.
2026-05-26 03:17:08 ------------------------
2026-05-26 03:17:09 ✅ nginx erfolgreich neu geladen.
2026-05-26 03:17:09 🏁 Zertifikatsprüfung abgeschlossen.
```

Beispiel mit CloudPanel-Oberfläche:

```text
2026-05-26 03:17:01 ===== Start Zertifikatsprüfung =====
2026-05-26 03:17:01 🔁 Zertifikat für panel.example.com läuft in 5 Tagen ab – erneuere.
2026-05-26 03:17:01 🔐 Erneuere CloudPanel-Oberflächen-Zertifikat für panel.example.com.
2026-05-26 03:17:02 ℹ️  Nutze certbot standalone. nginx wird kurz gestoppt.
2026-05-26 03:17:08 📄 CloudPanel-Oberflächen-Zertifikat erfolgreich nach custom-domain.crt/key kopiert.
2026-05-26 03:17:09 ✅ nginx erfolgreich neu geladen.
2026-05-26 03:17:09 ------------------------
2026-05-26 03:17:10 ✅ Zertifikat für example.com ist noch 42 Tage gültig – überspringe.
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

### Zertifikat einer normalen Website prüfen

```bash
openssl x509 -in /etc/nginx/ssl-certificates/muster.de.crt -noout -dates
```

---

### Zertifikat der CloudPanel-Oberfläche prüfen

```bash
openssl x509 -in /etc/nginx/ssl-certificates/custom-domain.crt -noout -dates
```

---

### Log live ansehen

```bash
sudo tail -f /var/log/cloudpanel-certificate-auto.log
```

---

## 🧾 Hinweise

- Normale Websites werden über CloudPanel selbst erneuert.
- Das Skript nutzt für normale Sites kein direktes `certbot --webroot` mehr.
- Dadurch sind Reverse-Proxy-Sites und Weiterleitungen weniger problematisch.
- Die CloudPanel-Oberfläche wird separat über `custom-domain.crt` und `custom-domain.key` behandelt.
- `custom-domain` wird nicht als normale Website verarbeitet.
- Für die CloudPanel-Oberfläche wird bei `PANEL_USE_STANDALONE=true` nginx kurz gestoppt.
- Vor dem Überschreiben vorhandener Zertifikatsdateien werden Backups erstellt.
- Das Skript verhindert parallele Ausführungen über ein Lockfile.
- Das Skript sollte als root ausgeführt werden.
- Das Skript ersetzt kein vollständiges Server-Backup.

---

## ⚠️ Wichtiger Hinweis zu Alias-Domains / SAN

Dieses Skript erkennt Domains anhand einzelner Zertifikatsdateien:

```text
/etc/nginx/ssl-certificates/domain.de.key
```

und erneuert dann diese Domain mit:

```bash
clpctl lets-encrypt:install:certificate --domainName=domain.de
```

Wenn eine CloudPanel-Site mehrere Domains oder Alias-Domains in einem Zertifikat verwendet, zum Beispiel:

```text
example.com
www.example.com
```

dann muss geprüft werden, ob CloudPanel diese automatisch berücksichtigt.

Falls nicht, muss das Skript später um `--subjectAlternativeName` erweitert werden.

Beispiel:

```bash
clpctl lets-encrypt:install:certificate \
  --domainName=example.com \
  --subjectAlternativeName=www.example.com
```

---

## 🛠️ Fehlerbehebung

### ❌ CloudPanel-Erneuerung schlägt fehl

Wenn im Log steht:

```text
CloudPanel Let's-Encrypt-Fehler bei example.com
```

teste den CloudPanel-Befehl manuell:

```bash
sudo clpctl lets-encrypt:install:certificate --domainName=example.com
```

Prüfe außerdem:

```bash
dig +short example.com
curl -I http://example.com
sudo nginx -t
```

---

### ❌ CloudPanel-Oberfläche wird nicht erneuert

Prüfe, ob `PANEL_DOMAIN` korrekt gesetzt ist:

```bash
grep PANEL_DOMAIN /usr/local/bin/clp-ssl-renew.sh
```

Prüfe außerdem:

```bash
ls -lah /etc/nginx/ssl-certificates/custom-domain.*
```

Wenn `PANEL_DOMAIN` leer ist, wird die CloudPanel-Oberfläche bewusst übersprungen.

---

### ❌ certbot fehlt

Wenn du die CloudPanel-Oberfläche erneuern möchtest, muss certbot installiert sein:

```bash
sudo apt update
sudo apt install -y certbot
```

Für normale CloudPanel-Websites ist certbot im Skript nicht direkt nötig, weil `clpctl` genutzt wird.

---

### ❌ nginx startet nach der Panel-Erneuerung nicht

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

### ⚠️ Meldung: Ein anderer Lauf ist bereits aktiv

Wenn im Log steht:

```text
Ein anderer Lauf ist bereits aktiv – beende.
```

läuft das Skript bereits oder ein vorheriger Lauf hängt noch.

Prüfen:

```bash
ps aux | grep clp-ssl-renew
ps aux | grep certbot
```

---

## 🧹 Alte Logs prüfen

```bash
sudo tail -n 200 /var/log/cloudpanel-certificate-auto.log
```

Certbot-Log, relevant für die CloudPanel-Oberfläche:

```bash
sudo tail -n 200 /var/log/letsencrypt/letsencrypt.log
```

---

## 📝 Lizenz

MIT License – du darfst das Skript frei verwenden, anpassen und weitergeben.

---

## 👨‍💻 Autor

Erstellt von [qttx-dev](https://github.com/qttx-dev)

Pull Requests, Issues und ⭐ sind willkommen!
