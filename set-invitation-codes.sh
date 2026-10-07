#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

View or update guest registration invitation codes on a Keycloak realm.
Codes are stored as the 'invitation_codes' realm attribute (JSON).
If no action flag is provided, the current codes are displayed.

Required:
  --host       URL     Keycloak host URL (e.g. https://keycloak.example.com)
  --username   USER    Admin username
  --password   PASS    Admin password

Actions (omit all to view current codes):
  --json       JSON    Set the entire invitation codes JSON (replaces all codes)
  --file       PATH    Set codes from a JSON file (replaces all codes)
  --add        CODE    Add a new code (requires at least one --group; optional --description)
  --remove     CODE    Remove an existing code
  --enable     CODE    Enable an existing code
  --disable    CODE    Disable an existing code

Options for --add:
  --group      NAME    Group name to assign (repeatable for multiple groups)
  --description TEXT   Description for the code (optional, defaults to "")

Examples:
  # View current codes
  $(basename "$0") --host https://kc.example.com --username admin --password secret

  # Set all codes from JSON string
  $(basename "$0") --host https://kc.example.com --username admin --password secret \\
    --json '{"GUEST2024":{"groupNames":["Guest Users - Basic"],"enabled":true,"description":"Basic guest access"}}'

  # Set all codes from file
  $(basename "$0") --host https://kc.example.com --username admin --password secret \\
    --file invitation-codes.json

  # Add a code with one group
  $(basename "$0") --host https://kc.example.com --username admin --password secret \\
    --add NEWCODE --group "Guest Users - Basic" --description "New guest code"

  # Add a code with multiple groups
  $(basename "$0") --host https://kc.example.com --username admin --password secret \\
    --add RESEARCH2024 --group "Guest Users - Researcher" --group "JupyterHub Users" --description "Researcher access"

  # Disable a code
  $(basename "$0") --host https://kc.example.com --username admin --password secret \\
    --disable GUEST2024

  # Enable a code
  $(basename "$0") --host https://kc.example.com --username admin --password secret \\
    --enable GUEST2024

  # Remove a code
  $(basename "$0") --host https://kc.example.com --username admin --password secret \\
    --remove OLDCODE
EOF
  exit 1
}

KEYCLOAK_HOST=""
ADMIN_USER=""
ADMIN_PASS=""
ACTION=""        # set, add, remove, enable, disable
JSON_VALUE=""
JSON_FILE=""
CODE_NAME=""
CODE_GROUPS=()
DESCRIPTION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)        KEYCLOAK_HOST="$2"; shift 2 ;;
    --username)    ADMIN_USER="$2";    shift 2 ;;
    --password)    ADMIN_PASS="$2";    shift 2 ;;
    --json)        ACTION="set"; JSON_VALUE="$2"; shift 2 ;;
    --file)        ACTION="set"; JSON_FILE="$2";  shift 2 ;;
    --add)         ACTION="add"; CODE_NAME="$2";  shift 2 ;;
    --remove)      ACTION="remove"; CODE_NAME="$2"; shift 2 ;;
    --enable)      ACTION="enable"; CODE_NAME="$2"; shift 2 ;;
    --disable)     ACTION="disable"; CODE_NAME="$2"; shift 2 ;;
    --group)       CODE_GROUPS+=("$2");    shift 2 ;;
    --description) DESCRIPTION="$2";  shift 2 ;;
    -h|--help)     usage ;;
    *)             echo "Unknown option: $1"; usage ;;
  esac
done

# Validate required args
if [[ -z "$KEYCLOAK_HOST" || -z "$ADMIN_USER" || -z "$ADMIN_PASS" ]]; then
  echo "Error: --host, --username, and --password are required."
  usage
fi

# Validate --add requires at least one --group
if [[ "$ACTION" == "add" && ${#CODE_GROUPS[@]} -eq 0 ]]; then
  echo "Error: --add requires at least one --group to specify the target group name(s)."
  exit 1
fi

# Load JSON from file if provided
if [[ -n "$JSON_FILE" ]]; then
  if [[ ! -f "$JSON_FILE" ]]; then
    echo "Error: File not found: $JSON_FILE"
    exit 1
  fi
  JSON_VALUE=$(cat "$JSON_FILE")
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

# Fetch current invitation codes from realm
fetch_current_codes() {
  local raw
  raw=$(curl -sf "${KEYCLOAK_HOST}/admin/realms/veda" \
    -H "Authorization: Bearer ${TOKEN}" | jq -r '.attributes.invitation_codes // ""')
  if [[ -z "$raw" || "$raw" == "null" ]]; then
    echo "{}"
  else
    echo "$raw"
  fi
}

# Update the invitation_codes realm attribute
update_codes() {
  local codes_json="$1"
  # Fetch the full current attributes map and merge only invitation_codes into it.
  # A Keycloak realm PUT replaces the entire attributes map, so we must re-send the
  # existing attributes (e.g. ssoEmailWhitelist) or they would be wiped.
  local current_attrs payload
  current_attrs=$(curl -sf "${KEYCLOAK_HOST}/admin/realms/veda" \
    -H "Authorization: Bearer ${TOKEN}" | jq '.attributes // {}')
  payload=$(echo "$current_attrs" | jq --arg codes "$codes_json" \
    '{attributes: (. + {invitation_codes: $codes})}')

  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "${KEYCLOAK_HOST}/admin/realms/veda" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$payload")

  if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo "Success! Invitation codes updated (HTTP ${HTTP_CODE})."
  else
    echo "Error: Failed to update invitation codes (HTTP ${HTTP_CODE})."
    exit 1
  fi
}

if [[ "$ACTION" == "set" ]]; then
  # Validate JSON
  if ! echo "$JSON_VALUE" | jq . >/dev/null 2>&1; then
    echo "Error: Invalid JSON provided."
    exit 1
  fi
  echo "Token obtained. Setting invitation codes..."
  update_codes "$JSON_VALUE"

elif [[ "$ACTION" == "add" ]]; then
  echo "Token obtained. Adding code '${CODE_NAME}'..."
  current=$(fetch_current_codes)
  # Check if code already exists
  if echo "$current" | jq -e --arg code "$CODE_NAME" 'has($code)' >/dev/null 2>&1; then
    echo "Error: Code '${CODE_NAME}' already exists. Use --enable/--disable to toggle, or --remove first."
    exit 1
  fi
  # Build groupNames JSON array from --group flags
  groups_json=$(printf '%s\n' "${CODE_GROUPS[@]}" | jq -R . | jq -s .)
  updated=$(echo "$current" | jq --arg code "$CODE_NAME" \
    --argjson groups "$groups_json" \
    --arg desc "$DESCRIPTION" \
    '. + {($code): {"groupNames": $groups, "enabled": true, "description": $desc}}')
  update_codes "$updated"

elif [[ "$ACTION" == "remove" ]]; then
  echo "Token obtained. Removing code '${CODE_NAME}'..."
  current=$(fetch_current_codes)
  if ! echo "$current" | jq -e --arg code "$CODE_NAME" 'has($code)' >/dev/null 2>&1; then
    echo "Error: Code '${CODE_NAME}' not found."
    exit 1
  fi
  updated=$(echo "$current" | jq --arg code "$CODE_NAME" 'del(.[$code])')
  update_codes "$updated"

elif [[ "$ACTION" == "enable" ]]; then
  echo "Token obtained. Enabling code '${CODE_NAME}'..."
  current=$(fetch_current_codes)
  if ! echo "$current" | jq -e --arg code "$CODE_NAME" 'has($code)' >/dev/null 2>&1; then
    echo "Error: Code '${CODE_NAME}' not found."
    exit 1
  fi
  updated=$(echo "$current" | jq --arg code "$CODE_NAME" '.[$code].enabled = true')
  update_codes "$updated"

elif [[ "$ACTION" == "disable" ]]; then
  echo "Token obtained. Disabling code '${CODE_NAME}'..."
  current=$(fetch_current_codes)
  if ! echo "$current" | jq -e --arg code "$CODE_NAME" 'has($code)' >/dev/null 2>&1; then
    echo "Error: Code '${CODE_NAME}' not found."
    exit 1
  fi
  updated=$(echo "$current" | jq --arg code "$CODE_NAME" '.[$code].enabled = false')
  update_codes "$updated"
fi

# Always display current codes at the end
echo ""
echo "Current invitation codes:"
fetch_current_codes | jq .
