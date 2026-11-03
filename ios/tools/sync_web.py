#!/usr/bin/env python3
"""Copy the web game (../../index.html) into the iOS app bundle as ios/AnimalSanctuary/Game/index.html.

Run it from anywhere after changing the game:

    python3 ios/tools/sync_web.py          # writes the app's copy
    python3 ios/tools/sync_web.py --check  # exits 1 if the app's copy is out of date (CI uses this)

What changes on the way in (each step fails loudly if the game no longer matches what it expects):
  * Google Fonts are swapped for the copies bundled next to index.html, so the app looks right offline.
  * PeerJS (co-op outside of Claude) loads from the bundled peerjs.min.js instead of unpkg.
  * Cabinets listed in IOS_HIDDEN_CABINETS are left out of the arcade, and the rest of the hall closes the gap.
  * A small marker (<meta name="as-platform" content="ios">) lets the page know it is in the app.

Saving is not changed here: the app injects Game/ios-bridge.js at launch, which mirrors localStorage into
native files (see SaveStore.swift).
"""
import pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / 'index.html'
DST = ROOT / 'ios' / 'AnimalSanctuary' / 'Game' / 'index.html'

# The BBS cabinet opens a live message board where strangers can post. App Review treats that as
# user-generated content (guideline 1.2: it needs reporting, blocking and filtering), so it stays web-only for now.
IOS_HIDDEN_CABINETS = ['MEGAzine BBS']

FONT_CSS = """<style>/* bundled fonts (SIL Open Font License, see *-OFL.txt) */
@font-face{font-family:'Pixelify Sans';src:url('PixelifySans-Variable.ttf') format('truetype');font-weight:400 700;font-display:swap}
@font-face{font-family:'Silkscreen';src:url('Silkscreen-Regular.ttf') format('truetype');font-weight:400;font-display:swap}
@font-face{font-family:'Silkscreen';src:url('Silkscreen-Bold.ttf') format('truetype');font-weight:700;font-display:swap}
</style>"""


def must_replace(s, old, new, what):
    if s.count(old) != 1:
        sys.exit(f'sync_web: expected exactly one {what} in index.html, found {s.count(old)}')
    return s.replace(old, new)


def build():
    s = SRC.read_text(encoding='utf-8')
    s = must_replace(s, '<link rel="preconnect" href="https://fonts.googleapis.com">\n', '', 'fonts preconnect')
    s = must_replace(s, '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>\n', '', 'gstatic preconnect')
    s = re.sub(r'<link rel="stylesheet" href="https://fonts\.googleapis\.com/css2\?[^"]*">', FONT_CSS, s, count=1)
    if 'fonts.googleapis.com' in s:
        sys.exit('sync_web: Google Fonts link not replaced')
    s = must_replace(s, "const PJ_URL='https://unpkg.com/peerjs@1.5.4/dist/peerjs.min.js';",
                     "const PJ_URL='peerjs.min.js';", 'PeerJS URL')
    s = must_replace(s, '<title>Animal Sanctuary</title>',
                     '<title>Animal Sanctuary</title>\n<meta name="as-platform" content="ios">', 'title')

    # arcade: drop hidden cabinets, then re-pack the main hall (back-room attractions keep their spots)
    a = s.index('const CABS=[')
    b = s.index('];', a) + 2
    entries = [ln.strip() for ln in s[a:b][len('const CABS=['):-2].split('\n') if ln.strip()]
    entries = [e[:-1] if e.endswith(',') else e for e in entries]
    kept = [e for e in entries if not any(e.startswith(f"{{name:'{n}'") for n in IOS_HIDDEN_CABINETS)]
    if len(entries) - len(kept) != len(IOS_HIDDEN_CABINETS):
        sys.exit('sync_web: could not find every hidden cabinet in CABS')
    slot = 1
    for k, e in enumerate(kept):
        if 'back:' not in e:
            kept[k] = re.sub(r',i:\d+,', f',i:{slot},', e, count=1)
            slot += 2
    block = 'const CABS=[\n ' + ',\n '.join(kept) + '];'
    s = s[:a] + block + s[b:]
    return s


def main():
    out = build()
    if '--check' in sys.argv:
        cur = DST.read_text(encoding='utf-8') if DST.exists() else ''
        if cur != out:
            sys.exit('ios/AnimalSanctuary/Game/index.html is out of date: run python3 ios/tools/sync_web.py')
        print('iOS web copy is up to date')
        return
    DST.write_text(out, encoding='utf-8')
    print(f'wrote {DST.relative_to(ROOT)} ({len(out):,} bytes)')


if __name__ == '__main__':
    main()
