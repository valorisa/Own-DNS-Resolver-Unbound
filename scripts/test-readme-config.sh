#!/usr/bin/env bash
# Valide les blocs YAML des sections 8.2 et 14.3, puis teste le scénario Termux.
extract() { awk "/^### $1/{f=1} f&&/^\`\`\`yaml/{b=1;next} b&&/^\`\`\`/{exit} b" README.md; }
for sec in '8\.2' '14\.3'; do
  { printf 'server:\n    username: ""\n    chroot: ""\n'; extract "$sec"; } > "${TMPDIR:-/tmp}/readme-test.conf"
  echo "== section $sec"; unbound-checkconf "${TMPDIR:-/tmp}/readme-test.conf" || exit 1
done
echo "== scénario Termux (port 5335)"
extract '14\.3' > "$HOME/unbound-termux.conf"
unbound -d -c "$HOME/unbound-termux.conf" & PID=$!
sleep 3
dig -p 5335 next.ink @127.0.0.1 +short
dig -p 5335 dnssec-failed.org @127.0.0.1 | grep 'status:'
kill $PID
