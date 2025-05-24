# 🔒 AutoSSL für CloudPanel

![Bash Script](https://img.shields.io/badge/script-bash-green?logo=gnu-bash)
![LetsEncrypt](https://img.shields.io/badge/ssl-Let's%20Encrypt-blue?logo=letsencrypt)
![CloudPanel](https://img.shields.io/badge/CloudPanel-Compatible-yellow?logo=linux)
![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)

Automatisiertes Bash-Skript für die Erneuerung und Installation von Let's Encrypt SSL-Zertifikaten in **CloudPanel**-Installationen – ohne `site:list`-Kommando, vollständig filesystem-basiert.

---

## ✅ Features

- Automatische Erkennung aller Domains via `/home/*/htdocs/*`
- Prüfung des Ablaufdatums der Zertifikate
- Erneuerung via `certbot` im Webroot-Modus
- Automatische Kopie und Installation mit `clpctl site:install:certificate`
- Logging in `/var/log/cloudpanel-certificate-auto.log`

---

## 🔧 Anforderungen

- Linux (getestet mit Debian/Ubuntu)
- [`certbot`](https://certbot.eff.org/)
- CloudPanel 2.x oder 3.x
- Root-Zugriff oder Sudo

---

## 🛠️ Installation

1. Skript herunterladen:

```bash
wget https://github.com/qttx-dev/clp-ssl-renew/raw/main/clp-ssl.sh -O /usr/local/bin/clp-ssl-renew.sh
chmod +x /usr/local/bin/cloudpanel-autossl.sh
