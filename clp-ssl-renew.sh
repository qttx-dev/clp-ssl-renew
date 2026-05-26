#!/bin/bash
set -euo pipefail

CERT_DST_BASE="/etc/nginx/ssl-certificates"
CERT_SRC_BASE="/etc/letsencrypt/live"
LOGFILE="/var/log/cloudpanel-certificate-auto.log"

WARN_DAYS=14
CERTBOT_EMAIL="deine-mail@domain.de"

# Wichtig: Hier deine CloudPanel-Admin-Domain eintragen.
PANEL_DOMAIN="panel.deinedomain.de"

# Wenn true, wird bei der CloudPanel-Oberfläche certbot standalone genutzt.
# Dafür wird nginx kurz gestoppt.
PANEL_USE_STANDALONE=true

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOGFILE"
}

need_renewal() {
    local crt_path="$1"
    local domain="$2"

    if [[ ! -f "$crt_path" ]]; then
        log "⚠️  Kein Zertifikat für $domain gefunden – erneuere."
        return 0
    fi

    local enddate
    enddate=$(openssl x509 -enddate -noout -in "$crt_path" 2>/dev/null | cut -d= -f2 || true)

    if [[ -z "$enddate" ]]; then
        log "⚠️  Kein Ablaufdatum lesbar – erneuere $domain vorsichtshalber."
        return 0
    fi

    local end_ts now_ts days_left
    end_ts=$(date -d "$enddate" +%s)
    now_ts=$(date +%s)
    days_left=$(( (end_ts - now_ts) / 86400 ))

    if (( days_left <= WARN_DAYS )); then
        log "🔁 Zertifikat für $domain läuft in $days_left Tagen ab – erneuere."
        return 0
    fi

    log "✅ Zertifikat für $domain ist noch $days_left Tage gültig – überspringe."
    return 1
}

backup_cert_files() {
    local crt_path="$1"
    local key_path="$2"
    local ts
    ts=$(date '+%Y%m%d-%H%M%S')

    [[ -f "$crt_path" ]] && cp "$crt_path" "$crt_path.bak.$ts"
    [[ -f "$key_path" ]] && cp "$key_path" "$key_path.bak.$ts"
}

install_site_certificate() {
    local domain="$1"
    local crt_path="$2"
    local key_path="$3"

    if ! openssl x509 -in "$crt_path" -noout &>/dev/null; then
        log "❌ Zertifikat für $domain ist ungültig – Import übersprungen."
        return 1
    fi

    if clpctl site:install:certificate \
        --domainName="$domain" \
        --privateKey="$key_path" \
        --certificate="$crt_path" >> "$LOGFILE" 2>&1; then
        log "✅ CloudPanel-Site-Import für $domain erfolgreich."
    else
        log "❌ Fehler beim CloudPanel-Site-Import für $domain."
        return 1
    fi
}

renew_with_webroot() {
    local domain="$1"
    local webroot="$2"

    certbot certonly --webroot \
        -w "$webroot" \
        --agree-tos \
        --non-interactive \
        --email "$CERTBOT_EMAIL" \
        -d "$domain" >> "$LOGFILE" 2>&1
}

renew_panel_certificate() {
    local domain="$1"
    local crt_path="$CERT_DST_BASE/custom-domain.crt"
    local key_path="$CERT_DST_BASE/custom-domain.key"

    if [[ -z "$domain" || "$domain" == "panel.deinedomain.de" ]]; then
        log "❌ PANEL_DOMAIN ist nicht gesetzt. Bitte oben im Script korrekt eintragen."
        return 1
    fi

    if ! need_renewal "$crt_path" "$domain"; then
        return 0
    fi

    log "🔐 Erneuere CloudPanel-Oberflächen-Zertifikat für $domain."

    backup_cert_files "$crt_path" "$key_path"

    if [[ "$PANEL_USE_STANDALONE" == true ]]; then
        log "ℹ️  Nutze standalone-Modus. nginx wird kurz gestoppt."

        systemctl stop nginx

        if certbot certonly --standalone \
            --agree-tos \
            --non-interactive \
            --email "$CERTBOT_EMAIL" \
            -d "$domain" >> "$LOGFILE" 2>&1; then
            log "✅ Certbot standalone für $domain erfolgreich."
        else
            log "❌ Certbot standalone für $domain fehlgeschlagen."
            systemctl start nginx || true
            return 1
        fi

        systemctl start nginx
    else
        log "❌ PANEL_USE_STANDALONE=false ist aktuell nicht automatisch umgesetzt."
        return 1
    fi

    local src_dir="$CERT_SRC_BASE/$domain"

    if [[ ! -d "$src_dir" ]]; then
        log "❌ Let's-Encrypt-Quellverzeichnis für $domain nicht gefunden: $src_dir"
        return 1
    fi

    cp "$src_dir/fullchain.pem" "$crt_path"
    cp "$src_dir/privkey.pem" "$key_path"

    chmod 644 "$crt_path"
    chmod 600 "$key_path"

    if nginx -t >> "$LOGFILE" 2>&1; then
        systemctl reload nginx
        log "✅ CloudPanel-Oberflächen-Zertifikat installiert und nginx neu geladen."
    else
        log "❌ nginx-Konfiguration fehlerhaft. Bitte Backup-Zertifikat prüfen."
        return 1
    fi
}

log "===== Start Zertifikatsprüfung ====="

# === Webroots aus /home rekonstruieren ===
declare -A DOMAIN_WEBROOTS

shopt -s nullglob
for dir in /home/*/htdocs/*; do
    if [[ -d "$dir" ]]; then
        domain=$(basename "$dir")
        DOMAIN_WEBROOTS["$domain"]="$dir"
    fi
done

# === Erst CloudPanel-Oberfläche behandeln ===
if [[ -f "$CERT_DST_BASE/custom-domain.key" || -f "$CERT_DST_BASE/custom-domain.crt" ]]; then
    renew_panel_certificate "$PANEL_DOMAIN" || log "❌ CloudPanel-Oberflächen-Zertifikat konnte nicht erneuert werden."
else
    log "ℹ️  Kein custom-domain Zertifikat gefunden – CloudPanel-Oberfläche wird übersprungen."
fi

echo "------------------------" >> "$LOGFILE"

# === Normale CloudPanel-Site-Zertifikate prüfen ===
for key_path in "$CERT_DST_BASE"/*.key; do
    domain=$(basename "$key_path" .key)

    # CloudPanel-Oberfläche nicht wie eine normale Website behandeln
    if [[ "$domain" == "custom-domain" ]]; then
        log "ℹ️  custom-domain wurde separat behandelt – überspringe im Site-Loop."
        continue
    fi

    crt_path="$CERT_DST_BASE/$domain.crt"

    if [[ ! -f "$crt_path" ]]; then
        log "❌ Kein .crt für $domain – überspringe."
        continue
    fi

    webroot="${DOMAIN_WEBROOTS[$domain]:-}"

    if [[ -z "$webroot" || ! -d "$webroot" ]]; then
        log "❌ Webroot für $domain nicht gefunden – überspringe."
        continue
    fi

    if need_renewal "$crt_path" "$domain"; then
        log "🌐 Erneuere Site-Zertifikat für $domain über Webroot $webroot."

        backup_cert_files "$crt_path" "$key_path"

        if renew_with_webroot "$domain" "$webroot"; then
            src_dir="$CERT_SRC_BASE/$domain"

            if [[ -d "$src_dir" ]]; then
                cp "$src_dir/fullchain.pem" "$crt_path"
                cp "$src_dir/privkey.pem" "$key_path"

                chmod 644 "$crt_path"
                chmod 600 "$key_path"

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

    install_site_certificate "$domain" "$crt_path" "$key_path" || true

    echo "------------------------" >> "$LOGFILE"
done

if nginx -t >> "$LOGFILE" 2>&1; then
    systemctl reload nginx
    log "✅ nginx erfolgreich neu geladen."
else
    log "❌ nginx -t fehlgeschlagen. Bitte Log prüfen: $LOGFILE"
fi

log "🏁 Zertifikatsprüfung abgeschlossen."
