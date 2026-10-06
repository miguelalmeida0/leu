#!/usr/bin/env python3
"""Leu Felt design-system contract.

Replaces check-night-field.py. The palette moved from Night Field to Felt, so the palette
assertions moved with it; every behavioural invariant the old gate protected is preserved below,
and the locked design rules from docs/internal/redesign-handoff/04_LOCKED_DESIGN_RULES.md are now
enforced rather than left to review.
"""
from pathlib import Path
import plistlib
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
problems = []

def require(cond, msg):
    if not cond: problems.append(msg)

# --- Design system ownership -------------------------------------------------
design = (ROOT / 'Shelf/DesignSystem/LeuDesign.swift').read_text()
for token in ['0xB6C690', '0xC3D19F', '0xF8F1DE', '0x24301F', '0xB3261E', 'LeuType.sans', 'LeuType.serif']:
    require(token in design, f'Felt token missing: {token}')
type_system = (ROOT / 'Shelf/DesignSystem/LeuType.swift').read_text()
for face in ['Gabarito-ExtraBold', 'Literata-Regular', 'relativeTo:', 'CTFontManagerRegisterGraphicsFont']:
    require(face in type_system, f'Felt type system missing: {face}')
require('static let touchTarget: CGFloat = 44' in design, '44pt minimum target must stay in the system')

theme = (ROOT / 'Shelf/DesignSystem/ShelfTheme.swift').read_text()
require('LeuDesign' in theme, 'ShelfTheme must resolve to LeuDesign, not hold a second palette')

def strip_comments(text):
    """Scan code, not prose. A rule may name the thing it forbids in its own doc comment."""
    out = []
    for line in text.splitlines():
        stripped = line.lstrip()
        if stripped.startswith('//'): continue
        out.append(line.split('//')[0] if '//' in line else line)
    return '\n'.join(out)

all_swift_paths = list((ROOT / 'Shelf').rglob('*.swift'))
# LeuType is the one owner of custom faces; everything else goes through it.
typed_paths = [p for p in all_swift_paths if p.name != 'LeuType.swift']
all_swift = '\n'.join(strip_comments(p.read_text(errors='replace')) for p in typed_paths)

# --- Locked rule: never handwritten / script typography ----------------------
# This is a rule about type, not about vocabulary: the Release canvas is legitimately
# described as a scribble area. So the check looks at fonts actually used.
for family in ['SnellRoundhand', 'Zapfino', 'BradleyHand', 'MarkerFelt', 'Chalkduster',
               'Noteworthy', 'HomemadeApple', 'Caveat', 'DancingScript']:
    require(family not in all_swift, f'handwritten/script typeface is locked out: {family}')
require('.custom(' not in all_swift,
        'custom typefaces must go through LeuType so the two-voice ramp stays enforced')
require('design: .rounded' not in all_swift,
        'rounded system type reads as consumer-toy; Felt uses Gabarito and Literata only')

# --- Locked rule: no generic AI slop ----------------------------------------
for forbidden in ['ultraThinMaterial', 'thinMaterial', 'regularMaterial', 'thickMaterial', 'ultraThickMaterial']:
    require(forbidden not in all_swift, f'generic glassmorphism is locked out: {forbidden}')
for forbidden in ['sparkle', 'sparkles', 'wand.and.stars']:
    require(forbidden not in all_swift, f'sparkle-as-intelligence iconography is locked out: {forbidden}')

# --- Locked rule: one persistent navigation level ---------------------------
root_view = (ROOT / 'Shelf/App/RootView.swift').read_text()
require('ShelfSectionSwitcher(' not in root_view, 'legacy two-tier navigation returned')
require('PrimaryTabBar(selection:' in root_view, 'the single persistent navigation level must be PrimaryTabBar')
tab_bar = (ROOT / 'Shelf/Learning/Components/PrimaryTabBar.swift').read_text()
require('Capsule' in tab_bar, 'compact primary navigation is a floating felt pill')
require('minHeight: LeuDesign.touchTarget' in tab_bar, 'primary navigation must keep 44pt targets')
for screen in ['Shelf/Learning/StudyLandingScreen.swift', 'Shelf/Learning/TrailsScreen.swift']:
    path = ROOT / screen
    if path.exists():
        require('PrimaryTabBar(' not in path.read_text(),
                f'no second global navigation inside {screen}')

# --- Preserved invariants from the previous gate ----------------------------
library = (ROOT / 'Shelf/Features/Library/Components/LibraryHeader.swift').read_text()
needle_start = library.find('struct OnTheNeedle')
needle = library[needle_start:] if needle_start >= 0 else ''
require(needle_start >= 0, 'OnTheNeedle resume strip missing')
for forbidden in ['tree', 'foliage', 'leaf.fill', 'leaf.circle', 'OpeningScene']:
    require(forbidden.lower() not in needle.lower(),
            f'resume surface must never use tree/foliage imagery: {forbidden}')
require('Pick it back up' in needle and 'You stopped on p.' in needle, 'resume line must name the real book and page')

reader_top = (ROOT / 'Shelf/Features/Reader/Components/ReaderTopBar.swift').read_text()
reader_bottom = (ROOT / 'Shelf/Features/Reader/Components/ReaderBottomBar.swift').read_text()
require('reader-context-return' in reader_top, 'source-return affordance must be visible')
require('reader-search-return' in reader_bottom, 'search-return affordance must be visible')

connections = (ROOT / 'Shelf/Knowledge/Components/ConnectedPassageSheet.swift').read_text()
require('Save connection' in connections, 'one-action connection save missing')

plist = plistlib.loads((ROOT / 'Shelf/Resources/Info.plist').read_bytes())
require(plist.get('CFBundleDisplayName') == 'Leu', 'installed app name must be Leu')

# --- Reading wins ------------------------------------------------------------
preferences = (ROOT / 'Shelf/Support/AppPreferences.swift').read_text()
require('readingBackground' in preferences and 'readingText' in preferences,
        'the reader must keep its own paper/warm/dark appearance independent of the shell')

# These are deliberately narrow regression alarms, not a SwiftUI accessibility parser.
for path in all_swift_paths:
    code = strip_comments(path.read_text(errors='replace'))
    name = str(path.relative_to(ROOT))
    require(not re.search(r'\.\s*material\b|\bMaterial\s*[.(]', code),
            f'{name}: material surface needs removal')
    # Only SwiftUI files can present a system menu; a model type named Menu is not one.
    require('import SwiftUI' not in code or not re.search(r'\bMenu\s*[({]|\.contextMenu\b|\.pickerStyle\(\.menu\)', code),
            f'{name}: use an opaque Leu menu/inline picker')
    for number, line in enumerate(code.splitlines(), 1):
        require(not re.search(r'foreground(?:Style|Color)\([^\n]*\.opacity\(', line),
                f'{name}:{number}: foreground opacity is not a typography token')
        if 'Text(' in line:
            require(not re.search(r'\.opacity\(0\.[0-6]\d*\)', line),
                    f'{name}:{number}: low-opacity text needs an explicit foreground')
    # A known signal-fill file with an explicit white label is suspicious. This alarm
    # intentionally does not infer arbitrary computed fill colors or view ancestry.
    if re.search(r'(?:LeuDesign.signal|ShelfTheme.(?:action|olive))', code):
        require(not re.search(r'foreground(?:Style|Color)\([^\n]*(?:Color\.)?\bwhite\b', code),
                f'{name}: white foreground in a signal-fill component')

for token in ['surfacePrimary', 'surfaceSecondary', 'surfaceRaised', 'textPrimary',
              'textSecondary', 'textTertiary', 'onSignal', 'signalText', 'fieldSurface',
              'fieldForeground', 'fieldPlaceholder', 'menuSurface', 'menuForeground',
              'menuSecondary', 'separator', 'successForeground', 'warningForeground', 'dangerForeground']:
    require(f'static let {token} =' in design, f'Semantic contrast token missing: {token}')

if problems:
    print('FAIL: Leu Felt design contract')
    for p in problems: print(' -', p)
    sys.exit(1)
print('PASS: Felt system, semantic state colour, one-tier IA, locked-out '
      'script/glass/sparkle tropes, and preserved return paths.')
