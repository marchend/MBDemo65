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
#
# `plutil` write failures, on the other hand, ARE surfaced — as Xcode
# `warning:` lines from the `inject()` helper. A silently-swallowed
# `plutil` failure would leave the sentinel in place and the app would
# boot into the "not configured" banner with no build-time signal about
# what actually went wrong. The "never hard-fail" rule applies only to
# missing env vars; downstream tooling failures should be visible.

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
    # Capture stderr so the plutil diagnostic ends up in the Xcode build log
    # alongside our `warning:` prefix (Xcode parses lines beginning with
    # `warning:` and surfaces them in the Issue Navigator).
    local plutil_err
    if ! plutil_err="$(/usr/bin/plutil -replace "${key}" -string "${value}" "${PLIST}" 2>&1)"; then
        echo "warning: InjectOktaConfig.sh: plutil -replace ${key} failed on ${PLIST}: ${plutil_err}"
        return 1
    fi
}

# Track whether any inject() call failed so we can emit a single summary
# warning at the end. We intentionally do NOT `exit 1` — that would break
# CI builds running without Okta secrets — but the per-key `warning:`
# lines above (plus this summary) ensure plutil failures are visible in
# the build log and Issue Navigator rather than silently swallowed.
inject_failures=0
inject "OktaIssuer"      "${OKTA_ISSUER:-}"      || inject_failures=$((inject_failures + 1))
inject "OktaClientID"    "${OKTA_CLIENT_ID:-}"   || inject_failures=$((inject_failures + 1))
inject "OktaRedirectURI" "${OKTA_REDIRECT_URI:-}" || inject_failures=$((inject_failures + 1))
inject "OktaScopes"      "${OKTA_SCOPES:-}"      || inject_failures=$((inject_failures + 1))

if [ "${inject_failures}" -gt 0 ]; then
    echo "warning: InjectOktaConfig.sh: ${inject_failures} plutil write(s) failed — Info.plist may contain stale sentinels; runtime will route to .notConfigured(reason:)"
fi

exit 0
