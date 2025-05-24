#!/bin/bash

set -euo pipefail

CERT_DST_BASE="/etc/nginx/ssl-certificates"
CERT_SRC_BASE="/etc/letsencrypt/live"
LOGFILE="/var/log/cloudpanel-certificate-auto.log"
WARN_DAYS=14
CERTBOT_EMAIL="deine-mail@domain.de"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOGFILE"
}

log "===== Start Zertifikatsprüfung ====="

# === Webroots aus /home/ rekonstruieren ===
declare -A DOMAIN_WEBROOTS

for dir in /home/*/htdocs/*; do
    if [[ -d "$dir" ]]; then
        domain=$(basename "$dir")
        DOMAIN_WEBROOTS["$domain"]="$dir"
    fi
done

# === Zertifikate prüfen ===
shopt -s nullglob
for key_path in "$CERT_DST_BASE"/*.key; do
    domain=$(basename "$key_path" .key)
    crt_path="$CERT_DST_BASE/$domain.crt"

    webroot="${DOMAIN_WEBROOTS[$domain]:-}"
    if [[ -z "$webroot" || ! -d "$webroot" ]]; then
        log "❌ Webroot für $domain nicht gefunden – überspringe."
        continue
    fi

    if [[ ! -f "$crt_path" ]]; then
        log "❌ Kein .crt für $domain – überspringe."
        continue
    fi

    renew=false
    enddate=$(openssl x509 -enddate -noout -in "$crt_path" 2>/dev/null | cut -d= -f2 || true)
    if [[ -z "$enddate" ]]; then
        log "⚠️  Kein Ablaufdatum – erneuere $domain vorsichtshalber."
        renew=true
    else
        end_ts=$(date -d "$enddate" +%s)
        now_ts=$(date +%s)
        days_left=$(( (end_ts - now_ts) / 86400 ))
        if (( days_left <= WARN_DAYS )); then
            log "🔁 Zertifikat für $domain läuft in $days_left Tagen ab – erneuere."
            renew=true
        else
            log "✅ Zertifikat für $domain ist noch $days_left Tage gültig – überspringe."
        fi
    fi

    if [[ "$renew" == true ]]; then
        if certbot certonly --webroot -w "$webroot" \
            --agree-tos --non-interactive --email "$CERTBOT_EMAIL" \
            -d "$domain" >> "$LOGFILE" 2>&1; then

            src_dir="$CERT_SRC_BASE/$domain"
            if [[ -d "$src_dir" ]]; then
                cp "$src_dir/fullchain.pem" "$crt_path"
                cp "$src_dir/privkey.pem" "$key_path"
                log "📄 Zertifikat für $domain erfolgreich kopiert."
            else
                log "❌ Kein Quellverzeichnis für $domain gefunden – überspringe Kopieren."
                continue
            fi
        else
            log "❌ Certbot-Fehler bei $domain – überspringe."
            continue
        fi
    fi

    if openssl x509 -in "$crt_path" -noout &>/dev/null; then
        if clpctl site:install:certificate \
            --domainName="$domain" \
            --privateKey="$key_path" \
            --certificate="$crt_path" >> "$LOGFILE" 2>&1; then
            log "✅ Import für $domain erfolgreich."
        else
            log "❌ Fehler beim Import für $domain."
        fi
    else
        log "❌ Zertifikat für $domain ungültig – Import übersprungen."
    fi

    echo "------------------------" >> "$LOGFILE"
done

log "🏁 Zertifikatsprüfung abgeschlossen."
