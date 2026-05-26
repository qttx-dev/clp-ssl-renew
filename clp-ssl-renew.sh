#!/bin/bash
set -euo pipefail

# ==============================================================================
# CloudPanel AutoSSL – Let's Encrypt Automation Script
# ==============================================================================
# Normale CloudPanel-Sites:
#   -> werden über CloudPanels eigenen CLI-Befehl erneuert:
#      clpctl lets-encrypt:install:certificate --domainName=example.com
#
# CloudPanel-Oberfläche / Custom Domain:
#   -> wird separat über custom-domain.crt und custom-domain.key behandelt
# ==============================================================================

CERT_DST_BASE="/etc/nginx/ssl-certificates"
LOGFILE="/var/log/cloudpanel-certificate-auto.log"
WARN_DAYS=14

# Für normale CloudPanel-Sites wird diese Mail NICHT benötigt,
# weil clpctl die Ausstellung übernimmt.
# Für die CloudPanel-Oberfläche / custom-domain wird sie von certbot genutzt.
CERTBOT_EMAIL="deine-mail@domain.de"

# Optional: CloudPanel-Oberflächen-Domain eintragen.
# Beispiel:
# PANEL_DOMAIN="server.example.com"
#
# Leer lassen, wenn die CloudPanel-Oberfläche nicht durch dieses Script
# erneuert werden soll.
PANEL_DOMAIN=""

# Für die CloudPanel-Oberfläche wird certbot standalone genutzt.
# Dafür wird nginx kurz gestoppt.
PANEL_USE_STANDALONE=true

LOCKFILE="/var/run/clp-ssl-renew.lock"

log() {
    mkdir -p "$(dirname "$LOGFILE")"
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOGFILE"
}

# Parallelstarts verhindern
exec 9>"$LOCKFILE"
if ! flock -n 9; then
    log "⚠️  Ein anderer Lauf ist bereits aktiv – beende."
    exit 0
fi

check_requirements() {
    local missing=0

    for cmd in openssl nginx clpctl flock; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log "❌ Benötigter Befehl fehlt: $cmd"
            missing=1
        fi
    done

    if [[ -n "$PANEL_DOMAIN" ]]; then
        if ! command -v certbot >/dev/null 2>&1; then
            log "❌ certbot fehlt, wird aber für PANEL_DOMAIN benötigt."
            missing=1
        fi
    fi

    if [[ "$missing" -eq 1 ]]; then
        log "❌ Voraussetzungen nicht erfüllt – breche ab."
        exit 1
    fi
}

need_renewal() {
    local crt_path="$1"
    local domain="$2"

    if [[ ! -f "$crt_path" ]]; then
        log "⚠️  Kein Zertifikat für $domain gefunden – Erneuerung nötig."
        return 0
    fi

    local enddate
    enddate=$(openssl x509 -enddate -noout -in "$crt_path" 2>/dev/null | cut -d= -f2 || true)

    if [[ -z "$enddate" ]]; then
        log "⚠️  Ablaufdatum für $domain nicht lesbar – Erneuerung nötig."
        return 0
    fi

    local end_ts now_ts days_left

    if ! end_ts=$(date -d "$enddate" +%s 2>/dev/null); then
        log "⚠️  Ablaufdatum für $domain konnte nicht verarbeitet werden – Erneuerung nötig."
        return 0
    fi

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

reload_nginx() {
    if nginx -t >> "$LOGFILE" 2>&1; then
        systemctl reload nginx
        log "✅ nginx erfolgreich neu geladen."
    else
        log "❌ nginx -t fehlgeschlagen. Bitte prüfen: $LOGFILE"
        return 1
    fi
}

renew_site_with_cloudpanel() {
    local domain="$1"

    log "🌐 Erneuere Site-Zertifikat für $domain über CloudPanel."

    if clpctl lets-encrypt:install:certificate --domainName="$domain" >> "$LOGFILE" 2>&1; then
        log "✅ CloudPanel hat das Zertifikat für $domain erfolgreich erneuert und installiert."
        return 0
    fi

    log "❌ CloudPanel Let's-Encrypt-Fehler bei $domain."
    return 1
}

renew_panel_certificate() {
    local domain="$1"
    local crt_path="$CERT_DST_BASE/custom-domain.crt"
    local key_path="$CERT_DST_BASE/custom-domain.key"

    if [[ -z "$domain" ]]; then
        log "ℹ️  PANEL_DOMAIN ist leer – CloudPanel-Oberfläche wird übersprungen."
        return 0
    fi

    if [[ "$domain" == "panel.deinedomain.de" ]]; then
        log "❌ PANEL_DOMAIN enthält noch den Platzhalter. Bitte richtig setzen oder leer lassen."
        return 1
    fi

    if [[ "$CERTBOT_EMAIL" == "deine-mail@domain.de" || -z "$CERTBOT_EMAIL" ]]; then
        log "❌ CERTBOT_EMAIL ist nicht korrekt gesetzt. Für die Panel-Domain wird eine echte E-Mail benötigt."
        return 1
    fi

    if ! need_renewal "$crt_path" "$domain"; then
        return 0
    fi

    log "🔐 Erneuere CloudPanel-Oberflächen-Zertifikat für $domain."

    backup_cert_files "$crt_path" "$key_path"

    if [[ "$PANEL_USE_STANDALONE" != true ]]; then
        log "❌ PANEL_USE_STANDALONE=false wird aktuell nicht unterstützt."
        return 1
    fi

    log "ℹ️  Nutze certbot standalone. nginx wird kurz gestoppt."

    systemctl stop nginx

    local certbot_status=0

    certbot certonly --standalone \
        --agree-tos \
        --non-interactive \
        --email "$CERTBOT_EMAIL" \
        --cert-name "$domain" \
        -d "$domain" >> "$LOGFILE" 2>&1 || certbot_status=$?

    systemctl start nginx

    if [[ "$certbot_status" -ne 0 ]]; then
        log "❌ Certbot standalone für $domain fehlgeschlagen."
        reload_nginx || true
        return 1
    fi

    local src_dir="/etc/letsencrypt/live/$domain"

    if [[ ! -d "$src_dir" ]]; then
        log "❌ Let's-Encrypt-Quellverzeichnis nicht gefunden: $src_dir"
        reload_nginx || true
        return 1
    fi

    cp "$src_dir/fullchain.pem" "$crt_path"
    cp "$src_dir/privkey.pem" "$key_path"

    chmod 644 "$crt_path"
    chmod 600 "$key_path"

    if openssl x509 -in "$crt_path" -noout >/dev/null 2>&1; then
        log "📄 CloudPanel-Oberflächen-Zertifikat erfolgreich nach custom-domain.crt/key kopiert."
    else
        log "❌ Kopiertes Panel-Zertifikat ist ungültig."
        reload_nginx || true
        return 1
    fi

    reload_nginx
}

log "===== Start Zertifikatsprüfung ====="

check_requirements

# ------------------------------------------------------------------------------
# CloudPanel-Oberfläche / custom-domain separat behandeln
# ------------------------------------------------------------------------------
if [[ -f "$CERT_DST_BASE/custom-domain.crt" || -f "$CERT_DST_BASE/custom-domain.key" ]]; then
    renew_panel_certificate "$PANEL_DOMAIN" || log "❌ CloudPanel-Oberflächen-Zertifikat konnte nicht erneuert werden."
else
    log "ℹ️  Kein custom-domain Zertifikat gefunden – CloudPanel-Oberfläche wird übersprungen."
fi

echo "------------------------" >> "$LOGFILE"

# ------------------------------------------------------------------------------
# Normale CloudPanel-Site-Zertifikate prüfen und über clpctl erneuern
# ------------------------------------------------------------------------------
shopt -s nullglob

for key_path in "$CERT_DST_BASE"/*.key; do
    domain=$(basename "$key_path" .key)

    if [[ "$domain" == "custom-domain" ]]; then
        log "ℹ️  custom-domain wurde separat behandelt – überspringe im Site-Loop."
        echo "------------------------" >> "$LOGFILE"
        continue
    fi

    crt_path="$CERT_DST_BASE/$domain.crt"

    if need_renewal "$crt_path" "$domain"; then
        backup_cert_files "$crt_path" "$key_path"

        if renew_site_with_cloudpanel "$domain"; then
            if [[ -f "$crt_path" ]] && openssl x509 -in "$crt_path" -noout >/dev/null 2>&1; then
                log "✅ Zertifikat für $domain ist nach CloudPanel-Erneuerung vorhanden und gültig lesbar."
            else
                log "⚠️  CloudPanel meldete Erfolg, aber Zertifikat für $domain konnte nicht sauber geprüft werden."
            fi
        else
            log "❌ Erneuerung für $domain fehlgeschlagen – überspringe."
            echo "------------------------" >> "$LOGFILE"
            continue
        fi
    fi

    echo "------------------------" >> "$LOGFILE"
done

reload_nginx || true

log "🏁 Zertifikatsprüfung abgeschlossen."
