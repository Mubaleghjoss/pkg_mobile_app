# Offline Quran text attribution

The offline Arabic text in `assets/quran/uthmani.json` is the **Tanzil Quran
Text, Uthmani encoding, version 1.1** downloaded from
<https://tanzil.net/download/> on 2026-09-03.

Copyright © 2008–2021 Tanzil Project. The text may be copied and distributed
verbatim; changing the Quran text is not permitted. The source must be clearly
indicated and linked. See <https://tanzil.net/docs/Text_License> for the full
terms and <https://tanzil.net/updates/> for text updates.

Only packaging metadata (chapter number/name and ayah number) was added. The
Arabic lines were not edited. The asset contains 114 chapters and 6,236 ayahs;
the application validates these counts, sequential chapter/ayah numbering, and
non-empty text before use. Chapter display metadata was generated independently
from the public `risan/quran-json` dataset; it is not Quran text and can be
replaced without affecting the Tanzil text.

This reader and asset are not derived from Al-Furkan, qcf_quran, or their
branding/assets.
