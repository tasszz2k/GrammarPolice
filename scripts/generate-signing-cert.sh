#!/usr/bin/env bash
#
# Generate a stable self-signed code signing certificate for the
# GrammarPolice release pipeline.
#
# Run this ONCE on the maintainer's Mac. The resulting p12 must be
# reused for every future release, so back it up safely (e.g. password
# manager). Regenerating it would change the signing identity and
# revoke the macOS Accessibility grant on every existing user's Mac.
#
# Usage:
#   ./scripts/generate-signing-cert.sh
#
# Output: prints three values to stdout and copies the base64 p12 to
# the clipboard so you can paste each into a GitHub Actions secret:
#   - MACOS_CERT_P12_BASE64
#   - MACOS_CERT_PASSWORD
#   - MACOS_KEYCHAIN_PASSWORD
#
# Add the secrets at:
#   https://github.com/tasszz2k/GrammarPolice/settings/secrets/actions

set -euo pipefail

CERT_NAME="GrammarPolice Self-Signed"
OUT_DIR="$(mktemp -d)"
CERT_KEY="${OUT_DIR}/gp.key"
CERT_CRT="${OUT_DIR}/gp.crt"
CERT_P12="${OUT_DIR}/gp.p12"
CERT_CNF="${OUT_DIR}/gp.cnf"

CERT_PASSWORD=$(openssl rand -hex 16)
KEYCHAIN_PASSWORD=$(openssl rand -hex 16)

cat > "${CERT_CNF}" <<EOF
[req]
distinguished_name = dn
prompt = no
[dn]
CN = ${CERT_NAME}
[v3]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

echo "Generating 10-year RSA-2048 self-signed code signing cert..."
openssl req -x509 -newkey rsa:2048 \
  -keyout "${CERT_KEY}" \
  -out "${CERT_CRT}" \
  -days 3650 -nodes \
  -config "${CERT_CNF}" \
  -extensions v3 >/dev/null 2>&1

echo "Bundling key + cert into a password-protected PKCS#12 (legacy format)..."
# IMPORTANT: -legacy is required so that the macOS `security` command can
# decrypt the p12 inside GitHub Actions. OpenSSL 3.x defaults to
# PBES2 + AES-256 + HMAC-SHA-256, which `security import` cannot handle and
# fails with "MAC verification failed during PKCS12 import (wrong password?)".
# -legacy switches to pbeWithSHA1And40BitRC2-CBC + HMAC-SHA-1, which the
# system Security framework supports natively.
openssl pkcs12 -export -legacy \
  -inkey "${CERT_KEY}" \
  -in "${CERT_CRT}" \
  -name "${CERT_NAME}" \
  -out "${CERT_P12}" \
  -passout pass:"${CERT_PASSWORD}"

CERT_BASE64=$(base64 -i "${CERT_P12}")

if command -v pbcopy >/dev/null 2>&1; then
  printf "%s" "${CERT_BASE64}" | pbcopy
  CLIP_NOTE="(also copied to clipboard)"
else
  CLIP_NOTE=""
fi

cat <<EOF

============================================================
Generated successfully.

Add these three values as GitHub Actions secrets at:
  https://github.com/tasszz2k/GrammarPolice/settings/secrets/actions

------------------------------------------------------------
Secret name:  MACOS_CERT_P12_BASE64
Secret value: ${CLIP_NOTE}
${CERT_BASE64}

------------------------------------------------------------
Secret name:  MACOS_CERT_PASSWORD
Secret value:
${CERT_PASSWORD}

------------------------------------------------------------
Secret name:  MACOS_KEYCHAIN_PASSWORD
Secret value:
${KEYCHAIN_PASSWORD}

============================================================

IMPORTANT: back up the p12 + password somewhere safe (1Password,
encrypted USB, etc). If you lose them and have to regenerate the
cert, every existing user will be re-prompted for Accessibility
on their next upgrade. The whole point of this setup is identity
stability across releases.

A copy of the p12 was written to:
  ${CERT_P12}

You can shred it once the secrets are saved:
  shred -uz "${CERT_P12}" 2>/dev/null || rm -f "${CERT_P12}"
EOF
