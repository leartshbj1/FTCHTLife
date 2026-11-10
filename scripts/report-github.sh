#!/bin/bash
# Envoie le résultat de la compilation CircleCI sur GitHub (statut + commentaire avec les erreurs),
# pour que les fils de travail puissent lire le résultat sans accès à CircleCI.
# Nécessite la variable d'environnement GH_TOKEN (token GitHub : Commit statuses + Contents en écriture).
set -uo pipefail
[ -z "${GH_TOKEN:-}" ] && { echo "GH_TOKEN absent, pas de rapport GitHub."; exit 0; }

REPO="${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}"
SHA="${CIRCLE_SHA1}"
if grep -q "BUILD SUCCEEDED" build.log 2>/dev/null && [ -f output/FTCHTLife.ipa ]; then
  STATE=success; DESC="Compilation réussie, .ipa prêt"
else
  STATE=failure; DESC="La compilation a échoué"
fi

python3 - "$STATE" "$DESC" > /tmp/status.json <<'PY'
import json, os, sys
print(json.dumps({"state": sys.argv[1], "description": sys.argv[2], "context": "ipa", "target_url": os.environ.get("CIRCLE_BUILD_URL", "")}))
PY
curl -sS -X POST -H "Authorization: Bearer $GH_TOKEN" -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$REPO/statuses/$SHA" -d @/tmp/status.json > /dev/null

if [ "$STATE" = failure ]; then
  python3 - "$DESC" > /tmp/comment.json <<'PY'
import json, os, re, sys
log = open("build.log", errors="replace").read() if os.path.exists("build.log") else "(pas de build.log : échec avant la compilation, voir CircleCI)"
errs = [l for l in log.splitlines() if re.search(r"error:|JSON invalide|fatal", l)]
seen, out = set(), []
for l in errs:
    if l not in seen:
        seen.add(l); out.append(l)
body = "**Compilation CircleCI : échec** ([log](%s))\n\n```\n%s\n```\n" % (
    os.environ.get("CIRCLE_BUILD_URL", ""), "\n".join(out[:80]) or log[-6000:])
print(json.dumps({"body": body[:60000]}))
PY
  curl -sS -X POST -H "Authorization: Bearer $GH_TOKEN" -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$REPO/commits/$SHA/comments" -d @/tmp/comment.json > /dev/null
fi
echo "Rapport GitHub envoyé : $STATE"
