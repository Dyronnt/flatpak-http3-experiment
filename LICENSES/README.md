# License scope and provenance

- `../LICENSE`: MIT, covering original scripts, tests and documentation written
  for this repository, except third-party material explicitly identified below.
- `LGPL-2.0-or-later.txt`: verbatim OSTree `COPYING` from the audited source
  tree (GNU Library General Public License version 2). Applies to the material
  in `../patches/ostree-http3.patch` under the source file's `LGPL-2.0+` notice.
- `GPL-2.0-or-later.txt`: verbatim GNU GPL version 2 from the host's standard
  `/usr/share/common-licenses/GPL-2`, supplied as a companion license text.

The `or-later` names describe the source grant, not a modification to the license
texts. License documents retain their own copyright and verbatim-copy terms.
Upstream copyrights/notices are not replaced by this repository's MIT notice.

Dependencies are fetched separately at recorded commits. They are not vendored
or relicensed here. Their license/NOTICE files remain in their source trees.
See `../THIRD_PARTY_NOTICES.md`; inspect each project's individual files when
redistributing anything beyond this patch-and-scripts repository.
