#!/usr/bin/env bash
# Vérifie la section 24 du README contre l'article source.
ART="https://next.ink/260020/tuto-installer-facilement-son-propre-resolveur-dns-sur-raspberry-pi-vm-freebox-vps/"
page=$(curl -fsSL -A "Mozilla/5.0" "$ART") || { echo "ECHEC: article inaccessible"; exit 1; }
echo "== Termes repris de l'article"
for s in "Sébastien Gavois" "CVE-2026-50251" "dnssec-failed.org" "86.54.11.1" "joindns4.eu" "unwanted-reply-threshold"; do
  grep -qiF -- "$s" <<<"$page" && echo "OK      $s" || echo "ABSENT  $s"
done
echo "== Liens bortzmeyer dans l'article"
grep -oE 'https?://[^"<> )]*bortzmeyer[^"<> )]*' <<<"$page" | sort -u
echo "== Codes HTTP des URLs du README"
grep -oE 'https?://[^ )>"]+' README.md | sort -u | while read -r u; do
  printf '%s %s\n' "$(curl -o /dev/null -sL -m 15 -w '%{http_code}' -A 'Mozilla/5.0' "$u")" "$u"
done
