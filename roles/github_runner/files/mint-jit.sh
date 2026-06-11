#!/usr/bin/env bash
# Root-stage JIT minting (systemd ExecStartPre=+): authenticate as the
# GitHub App, mint a single-use JIT runner config, hand it to the runner
# user via the unit's runtime directory. The App key never becomes
# readable by the runner user (and therefore never by jobs).
#
# REPO-LEVEL registration: the runner is usable only by $GITHUB_ORG/$GITHUB_REPO
# (structural blast-radius limit — on the free plan, org-level Default-group
# runners would be reachable by every private repo in the org, and custom
# restricted runner groups need the Team plan). App perm: repo Administration:write.
#
# GITHUB_ORG / GITHUB_REPO / GITHUB_APP_CLIENT_ID / RUNNER_LABELS are
# provided by systemd's EnvironmentFile=/etc/github-runner/runner.env, which
# applies to every Exec line including this ExecStartPre stage — so no
# `source` of the env file (which would shell-evaluate secret values).
set -euo pipefail

KEY=/etc/github-runner/app.pem
OUT=/run/github-runner/jit

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

now=$(date +%s)
hdr=$(printf '{"alg":"RS256","typ":"JWT"}' | b64url)
pld=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' $((now - 60)) $((now + 600)) "$GITHUB_APP_CLIENT_ID" | b64url)
sig=$(printf '%s.%s' "$hdr" "$pld" | openssl dgst -sha256 -sign "$KEY" -binary | b64url)
jwt="$hdr.$pld.$sig"

inst=$(curl -sf -H "Authorization: Bearer $jwt" -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$GITHUB_ORG/$GITHUB_REPO/installation" | jq -r .id)

token=$(curl -sf -X POST -H "Authorization: Bearer $jwt" -H "Accept: application/vnd.github+json" \
  "https://api.github.com/app/installations/$inst/access_tokens" | jq -r .token)

labels=$(printf '%s' "$RUNNER_LABELS" | jq -R 'split(",")')
# runner_group_id is still a required field at the repo level; 1 = default.
curl -sf -X POST -H "Authorization: Bearer $token" -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$GITHUB_ORG/$GITHUB_REPO/actions/runners/generate-jitconfig" \
  -d "{\"name\":\"$(hostname)-$(date +%s)\",\"runner_group_id\":1,\"labels\":$labels}" \
  | jq -r .encoded_jit_config > "$OUT"

chown root:runner "$OUT"
chmod 0640 "$OUT"
