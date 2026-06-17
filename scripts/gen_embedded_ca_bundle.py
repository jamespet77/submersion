#!/usr/bin/env python3
"""Regenerate lib/core/network/embedded_ca_bundle.dart.

The embedded bundle is the *fallback* trust anchor set used on Windows when
the native certificate-store read fails or returns too few roots (see
app_security_context.dart). It is a plain concatenation of public root CA
certificates in PEM form, emitted as a Dart raw-string constant so the
SecurityContext can be built synchronously with no asset loading.

Source defaults to the host's system bundle. On macOS that is
/etc/ssl/cert.pem (the Mozilla-derived root set). Override with argv[1] to
pin a specific cacert.pem (e.g. a vendored https://curl.se/ca/cacert.pem).

Usage:
    python3 scripts/gen_embedded_ca_bundle.py [path-to-cacert.pem]
"""

import sys
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
OUT = REPO_ROOT / "lib" / "core" / "network" / "embedded_ca_bundle.dart"
DEFAULT_SOURCES = ["/etc/ssl/cert.pem", "/etc/ssl/certs/ca-certificates.crt"]

CERT_RE = re.compile(
    r"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----",
    re.DOTALL,
)


def main() -> int:
    source = None
    if len(sys.argv) > 1:
        source = Path(sys.argv[1])
    else:
        for candidate in DEFAULT_SOURCES:
            if Path(candidate).exists():
                source = Path(candidate)
                break
    if source is None or not source.exists():
        print(f"error: no CA bundle source found (tried {DEFAULT_SOURCES})")
        return 1

    text = source.read_text()
    certs = CERT_RE.findall(text)
    if not certs:
        print(f"error: no certificates found in {source}")
        return 1

    # Normalize to exactly one trailing newline per cert, joined with none.
    bundle = "\n".join(c.strip() for c in certs) + "\n"

    if "'''" in bundle:
        print("error: bundle contains triple-quote; cannot emit as raw string")
        return 1

    dart = (
        "// GENERATED FILE - DO NOT EDIT BY HAND.\n"
        "// Regenerate with: python3 scripts/gen_embedded_ca_bundle.py\n"
        f"// Source: {source} ({len(certs)} root certificates).\n"
        "//\n"
        "// Fallback trust anchors used on Windows when the native certificate\n"
        "// store read yields too few roots. See app_security_context.dart.\n"
        "library;\n"
        "\n"
        "/// Concatenated public root CA certificates in PEM form.\n"
        "const String embeddedCaBundlePem = r'''\n"
        f"{bundle}"
        "''';\n"
    )
    OUT.write_text(dart)
    print(f"wrote {OUT} ({len(certs)} certs, {len(dart)} bytes) from {source}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
