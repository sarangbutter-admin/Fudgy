#!/bin/bash
# Make a restore point of the current code. Usage: tools/backup.sh "short-label"
# Run it BEFORE each change. Saves the current commit on GitHub as a branch backup-<date>-<n>-<label>.
# (Netlify only builds the "dev" branch, so backup branches cost nothing.)
set -e
cd "$(dirname "$0")/.."
label=$(echo "${1:-update}" | tr -c 'a-zA-Z0-9\n' '-' | sed 's/-*$//' | cut -c1-40)
d=$(date +%Y-%m-%d)
n=$(git ls-remote --heads origin "backup-$d-*" | wc -l | tr -d ' '); n=$((n+1))
name="backup-$d-$(printf %02d $n)-$label"
git push -q origin "HEAD:refs/heads/$name"
echo "$name"
