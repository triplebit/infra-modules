#!/bin/bash
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
# GITHUB_ORG / GITHUB_REPO / GITHUB_APP_CLIENT_ID / RUNNER_LABELS come from a
# root-only mint.env file, separate from job-facing runner.env. The systemd
# unit runs this script through env -i so job credentials cannot affect root
# pre-start behavior via PATH, BASH_ENV, OPENSSL_CONF, etc.
set -euo pipefail

KEY=/etc/github-runner/app.pem
OUT=/run/github-runner/jit

set -a
. /etc/github-runner/mint.env
set +a

# Never leave a stale/empty jit for run.sh to trip over ("Not configured"):
# remove up front, write only after every API call demonstrably succeeded.
# -sS keeps curl quiet on success but PRINTS errors to stderr (-> journal);
# a bare `-sf ... | jq > $OUT` once failed silently AND left an empty file.
rm -f "$OUT"
fail() { echo "mint-jit: $1" >&2; exit 1; }

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

now=$(date +%s)
hdr=$(printf '{"alg":"RS256","typ":"JWT"}' | b64url)
pld=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' $((now - 60)) $((now + 600)) "$GITHUB_APP_CLIENT_ID" | b64url)
sig=$(printf '%s.%s' "$hdr" "$pld" | openssl dgst -sha256 -sign "$KEY" -binary | b64url)
jwt="$hdr.$pld.$sig"

inst=$(curl -sSf -H "Authorization: Bearer $jwt" -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$GITHUB_ORG/$GITHUB_REPO/installation" | jq -r '.id // empty') \
  || fail "installation lookup failed (HTTP error above)"
[ -n "$inst" ] || fail "no installation covering $GITHUB_ORG/$GITHUB_REPO (App not installed on the repo, or no repo access granted?)"

token=$(curl -sSf -X POST -H "Authorization: Bearer $jwt" -H "Accept: application/vnd.github+json" \
  "https://api.github.com/app/installations/$inst/access_tokens" | jq -r '.token // empty') \
  || fail "installation-token mint failed (HTTP error above; private key / Client ID mismatch?)"
[ -n "$token" ] || fail "could not mint installation token (private key / Client ID mismatch?)"

labels=$(printf '%s' "$RUNNER_LABELS" | jq -R 'split(",")')
# runner_group_id is still a required field at the repo level; 1 = default.
jit=$(curl -sSf -X POST -H "Authorization: Bearer $token" -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$GITHUB_ORG/$GITHUB_REPO/actions/runners/generate-jitconfig" \
  -d "{\"name\":\"$(hostname)-$(date +%s)\",\"runner_group_id\":1,\"labels\":$labels}" \
  | jq -r '.encoded_jit_config // empty') \
  || fail "generate-jitconfig failed (HTTP error above; 409 = Actions disabled on the repo, 403 = App permission update not approved, 404 = no repo access)"
[ -n "$jit" ] || fail "generate-jitconfig returned no config (App missing repo Administration:write, or the permission update not yet approved on the installation?)"

printf '%s' "$jit" > "$OUT"
chown root:runner "$OUT"
chmod 0640 "$OUT"
