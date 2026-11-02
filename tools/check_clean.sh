#!/bin/zsh
# Run before every commit and push. Fails if a tracked file holds personal data, secrets or machine paths.
#  - generic checks live here (safe to publish)
#  - personal strings live OUTSIDE the repo in ~/.repo-guard-patterns (one word per line, case-insensitive)
cd "$(dirname "$0")/.." || exit 2
files=$(git ls-files --cached --others --exclude-standard | grep -v -E '^tools/check_clean.sh$')
bad=0
check() {  # description, regex
  hits=$(echo "$files" | xargs grep -nIE "$2" 2>/dev/null)
  if [ -n "$hits" ]; then echo "FOUND ($1):"; echo "$hits" | cut -c1-140; bad=1; fi
}
check "email address"            '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[a-z]{2,}'
check "home folder path"         '/Users/[A-Za-z0-9._-]+|/home/[A-Za-z0-9._-]+'
check "private key block"        'BEGIN [A-Z ]*PRIVATE KEY'
check "token or key assignment"  '(ghp_|github_pat_|sk-[A-Za-z0-9]{20}|AKIA[0-9A-Z]{16}|api[_-]?key *[=:] *["'"'"'][^"'"'"']+)'
check "10-character team id"     '(DEVELOPMENT_TEAM|TEAM_ID) *[=:] *[A-Z0-9]{10}\b'
if [ -f "$HOME/.repo-guard-patterns" ]; then
  while IFS= read -r word; do
    [ -z "$word" ] && continue
    hits=$(echo "$files" | xargs grep -nIi -- "$word" 2>/dev/null)
    [ -n "$hits" ] && { echo "FOUND (personal word from ~/.repo-guard-patterns)"; echo "$hits" | cut -c1-140; bad=1; }
  done < "$HOME/.repo-guard-patterns"
else echo "note: ~/.repo-guard-patterns missing, only generic checks ran"; fi
ignored=$(git ls-files --cached | grep -E 'Local\.xcconfig$|\.env|\.p12|\.mobileprovision|\.pem$')
[ -n "$ignored" ] && { echo "FOUND (file that must never be tracked):"; echo "$ignored"; bad=1; }
[ $bad -eq 0 ] && echo "clean: nothing personal or secret found in $(echo "$files" | wc -l | tr -d ' ') files"
exit $bad
