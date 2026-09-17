#!/usr/bin/env bash
# Stores the FTP credentials of one website as GitHub secrets.
#   ./set-secrets.sh MitoMonkey/JustYogaRetreat
# The password is read without echo and never lands in shell history.
set -euo pipefail

repo="${1:?usage: $0 <owner/repo>}"

read -rp  "FTP server (w0xxxxxx.kasserver.com): " server
read -rp  "FTP user: " user
read -rsp "FTP password: " password; echo
read -rp  "Server dir, relative to the FTP login dir [./]: " dir

if [ -z "$server" ] || [ -z "$user" ] || [ -z "$password" ]; then
  echo "Server, user and password must not be empty. Nothing was saved." >&2
  exit 1
fi
dir="${dir:-./}"
case "$dir" in */) ;; *) dir="$dir/" ;; esac

gh secret set FTP_SERVER     -R "$repo" --body "$server"
gh secret set FTP_USERNAME   -R "$repo" --body "$user"
# Piped rather than passed as argument, so it never shows up in ps.
printf '%s' "$password" | gh secret set FTP_PASSWORD -R "$repo"
gh secret set FTP_SERVER_DIR -R "$repo" --body "$dir"

gh secret list -R "$repo"
