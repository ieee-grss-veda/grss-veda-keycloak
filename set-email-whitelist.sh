#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

View or update the SSO email whitelist on a Keycloak realm.
If neither --emails nor --file is provided, the current whitelist is displayed.

Required:
  --host       URL     Keycloak host URL (e.g. https://keycloak.example.com)
  --username   USER    Admin username
  --password   PASS    Admin password

Optional (omit both to view current whitelist):
  --emails     CSV     Comma-separated email patterns (e.g. "user@example.com,*@nasa.gov"). Use "" to clear.
  --file       PATH    Path to a file containing email patterns (one per line or comma-separated)

Example:
  $(basename "$0") --host https://keycloak.example.com --username admin --password secret
  $(basename "$0") --host https://keycloak.example.com --username admin --password secret --emails "user@example.com,*@nasa.gov"
  $(basename "$0") --host https://keycloak.example.com --username admin --password secret --file whitelist.txt
EOF
  exit 1
}

KEYCLOAK_HOST=""
ADMIN_USER=""
ADMIN_PASS=""
EMAILS=""
EMAIL_FILE=""
EMAILS_PROVIDED=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)     KEYCLOAK_HOST="$2"; shift 2 ;;
    --username) ADMIN_USER="$2";    shift 2 ;;
    --password) ADMIN_PASS="$2";    shift 2 ;;
    --emails)   EMAILS="$2"; EMAILS_PROVIDED=true; shift 2 ;;
    --file)     EMAIL_FILE="$2";    shift 2 ;;
    -h|--help)  usage ;;
    *)          echo "Unknown option: $1"; usage ;;
  esac
done

# Validate required args
if [[ -z "$KEYCLOAK_HOST" || -z "$ADMIN_USER" || -z "$ADMIN_PASS" ]]; then
  echo "Error: --host, --username, and --password are required."
  usage
fi

# Build whitelist string from file if provided
if [[ -n "$EMAIL_FILE" ]]; then
  EMAILS_PROVIDED=true
  if [[ ! -f "$EMAIL_FILE" ]]; then
    echo "Error: File not found: $EMAIL_FILE"
    exit 1
  fi
  # Read file, strip whitespace, skip blank lines, join with commas
  EMAILS=$(sed 's/^[[:space:]]*//;s/[[:space:]]*$//' "$EMAIL_FILE" \
    | grep -v '^$' \
    | paste -sd ',' -)
fi

# Strip trailing slash from host
KEYCLOAK_HOST="${KEYCLOAK_HOST%/}"

echo "Obtaining admin token from ${KEYCLOAK_HOST}..."

TOKEN=$(curl -sf -X POST "${KEYCLOAK_HOST}/realms/master/protocol/openid-connect/token" \
  -d "client_id=admin-cli" \
  -d "grant_type=password" \
  -d "username=${ADMIN_USER}" \
  -d "password=${ADMIN_PASS}" | jq -r '.access_token')

if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
  echo "Error: Failed to obtain admin token. Check your credentials and host URL."
  exit 1
fi

if [[ "$EMAILS_PROVIDED" == true ]]; then
  echo "Token obtained. Setting SSO email whitelist..."
  echo "Whitelist: ${EMAILS}"

  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "${KEYCLOAK_HOST}/admin/realms/veda" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"attributes\":{\"ssoEmailWhitelist\":\"${EMAILS}\"}}")

  if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo "Success! Email whitelist updated (HTTP ${HTTP_CODE})."
  else
    echo "Error: Failed to update whitelist (HTTP ${HTTP_CODE})."
    exit 1
  fi
fi

echo "Current whitelist:"
curl -s "${KEYCLOAK_HOST}/admin/realms/veda" \
  -H "Authorization: Bearer ${TOKEN}" | jq '.attributes.ssoEmailWhitelist'
