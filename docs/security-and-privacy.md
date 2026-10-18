# Security and privacy

Do not run scripts as root. Use a new private workspace under your home. Scripts
refuse unmarked nonempty workspaces and existing build/prefix outputs. Sources,
including Autotools-generated files, are written only into this new workspace.
They do not modify the original experiment or OS package configuration.

Private writable libraries must never be used by privileged services. The
experimental Flatpak has the system helper disabled; wrappers force user scope
and isolated state. No system service, Polkit policy, environment generator or
profile is activated. The existing session runtime directory is not replaced.
This is safety engineering, not a hardened sandbox against a malicious local
user, modified script, hostile Git configuration or hostile dependency build.

Keep TLS/hostname and OSTree GPG verification enabled. An insecure auxiliary
repository from the historical experiment was explicitly excluded. Do not use
`--no-gpg-verify`, `--insecure`, `tls-permissive` or global loader configuration
to make a test pass. QUIC does not replace content/signature validation.

`audit-linkage.py` invokes `ldd` only on trusted outputs in the private prefix.
Do not use it on untrusted downloaded executables. It checks resolved library
paths but is not a complete binary security audit.

## Before sharing or publishing

Verbose curl logs can contain IP addresses, usernames, absolute paths, proxy
credentials, Authorization/Cookie headers, signed URLs, query parameters,
client-certificate paths and installation details. Build metadata may capture
compiler environment and personal paths. Do not upload the workspace wholesale.

This repository includes only selected historical request/status lines with
addresses, headers and local paths omitted. They are labelled excerpts, not
complete traces; no automated general-purpose sanitizer is claimed.

The original six inspected HTTP logs had no matches in a targeted search for
Authorization/Cookie headers, URL userinfo or obvious token assignments. That
does not prove the entire original project is free of secrets.

Review the exact publication file list, licenses, attribution, nested `.git`
directories, generated files, secrets and log contents manually before any
commit or upload. `.gitignore` is defense in depth, not a security boundary.
