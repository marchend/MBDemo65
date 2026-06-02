#!/bin/bash
#
# InjectOktaConfig.sh — Xcode "Run Script" build phase.
#
# Reads four env vars from the calling process and writes them into the
# built Info.plist via `plutil -replace`. When an env var is unset, writes
# a recognisable sentinel value instead of hard-failing the build (so CI
# without real Okta credentials still produces a runnable app that boots
# into the "Okta is not configured" banner).
#
# Env vars consumed:
#   OKTA_ISSUER        → Info.plist key OktaIssuer
#   OKTA_CLIENT_ID     → Info.plist key OktaClientID
#   OKTA_REDIRECT_URI  → Info.plist key OktaRedirectURI
#   OKTA_SCOPES        → Info.plist key OktaScopes
#
# IMPORTANT: never `exit 1` on missing env vars. The runtime
# `OktaConfig.load()` detects the sentinel and routes control through
# `.notConfigured(reason:)`, which the LoginViewModel surfaces in the
# inline error banner. Hard-failing here would break CI builds that
# deliberately run with no Okta secrets.

set -u

SENTINEL="__OKTA_NOT_CONFIGURED__"

PLIST="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"

if [ ! -f "${PLIST}" ]; then
    echo "warning: InjectOktaConfig.sh: Info.plist not found at ${PLIST} — skipping injection"
    exit 0
fi

inject() {
    local key="$1"
    local value="$2"
    if [ -z "${value}" ]; then
        value="${SENTINEL}"
        echo "note: InjectOktaConfig.sh: ${key} not set in build env — wrote sentinel"
    fi
    /usr/bin/plutil -replace "${key}" -string "${value}" "${PLIST}"
}

inject "OktaIssuer"      "${OKTA_ISSUER:-}"
inject "OktaClientID"    "${OKTA_CLIENT_ID:-}"
inject "OktaRedirectURI" "${OKTA_REDIRECT_URI:-}"
inject "OktaScopes"      "${OKTA_SCOPES:-}"

exit 0
