#!/usr/bin/env python3
"""Deterministic WCAG checks against the actual Swift palette, not a copied palette.

This measures declared solid pairings only; it does not certify rendered screens.
"""
from pathlib import Path
import json
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


def luminance(rgb):
    def linear(byte):
        value = byte / 255
        return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4
    return sum(weight * linear(byte) for weight, byte in zip((0.2126, 0.7152, 0.0722), rgb))


def contrast(a, b):
    light, dark = sorted((luminance(a), luminance(b)), reverse=True)
    return (light + 0.05) / (dark + 0.05)


def palette():
    source = (ROOT / 'Shelf/DesignSystem/LeuDesign.swift').read_text()
    literals = dict(re.findall(r'static let (\w+) = Color\(hex: 0x([0-9A-Fa-f]{6})\)', source))
    aliases = dict(re.findall(r'static let (\w+) = (\w+)\s*$', source, re.M))

    def resolve(name, seen=()):
        if name in seen:
            raise ValueError(f'Cyclic color alias: {name}')
        if name in literals:
            value = int(literals[name], 16)
            return (value >> 16, (value >> 8) & 255, value & 255)
        return resolve(aliases[name], (*seen, name))

    return {name: resolve(name) for name in literals.keys() | aliases.keys()}


PAIRS = [
    (foreground, surface, 4.5 if foreground == 'textTertiary' else 7.0)
    for foreground in ('textPrimary', 'textSecondary', 'textTertiary')
    for surface in ('surfacePrimary', 'surfaceSecondary', 'surfaceRaised')
] + [
    ('onSignal', 'signal', 7), ('onSignal', 'signalPressed', 7),
    ('menuForeground', 'menuSurface', 7), ('menuSecondary', 'menuSurface', 7),
    ('fieldForeground', 'fieldSurface', 7), ('fieldPlaceholder', 'fieldSurface', 7),
    ('disabledForeground', 'disabledSurface', 4.5),
    ('successForeground', 'success', 7), ('warningForeground', 'warning', 7),
    ('dangerForeground', 'danger', 7),
    ('readingForeground', 'readingSurface', 7), ('readingSecondary', 'readingSurface', 7),
    ('signalText', 'readingSurface', 7),
    ('signal', 'fieldSurface', 3), ('success', 'surfaceRaised', 3),
    ('separator', 'fieldSurface', 3), ('separator', 'surfacePrimary', 3),
    ('separator', 'surfaceSecondary', 3), ('separator', 'menuSurface', 3),
    ('danger', 'menuSurface', 4.5), ('untested', 'surfaceRaised', 3),
]

PAIRS += [
    (foreground, surface, 4.5)
    for surface, foregrounds in (
        ('studyContinueSurface', ('studyContinueForeground', 'studyContinueSecondary')),
        ('studyFadingSurface', ('studyFadingForeground', 'studyFadingSecondary')),
        ('studyBlindSpotSurface', ('studyBlindSpotForeground', 'studyBlindSpotSecondary')),
        ('studyLabsSurface', ('studyLabsForeground', 'studyLabsSecondary', 'signal')),
    )
    for foreground in foregrounds
] + [('separator', 'studyLabsSurface', 3)]


class ContrastMathTests(unittest.TestCase):
    def test_black_white(self):
        self.assertAlmostEqual(contrast((0, 0, 0), (255, 255, 255)), 21)

    def test_identical(self):
        self.assertEqual(contrast((150, 180, 30), (150, 180, 30)), 1)

    def test_known_gray_and_symmetry(self):
        self.assertAlmostEqual(contrast((119, 119, 119), (255, 255, 255)), 4.478089, places=5)
        self.assertEqual(contrast((0, 20, 90), (100, 230, 240)), contrast((100, 230, 240), (0, 20, 90)))


class NightFieldPairTests(unittest.TestCase):
    pass


class CoverPairTests(unittest.TestCase):
    pass


def pair_test(foreground, surface, minimum):
    def test(self):
        colors = palette()
        self.assertGreaterEqual(contrast(colors[foreground], colors[surface]), minimum,
                                f'{foreground}/{surface} must meet {minimum}:1')
    return test


for foreground, surface, minimum in PAIRS:
    setattr(NightFieldPairTests, f'test_{foreground}_on_{surface}', pair_test(foreground, surface, minimum))


def cover_test(name, foreground):
    def test(self):
        source = (ROOT / 'Shelf/DesignSystem/ShelfTheme.swift').read_text()
        body = re.search(r'case \.' + name + r':(.+?)(?=case |\n        })', source, re.S)[1]
        colors = dict(re.findall(r'(background|foreground|muted) = Color\(hex: 0x([A-F0-9]{6})\)', body))
        ratio = contrast(tuple(bytes.fromhex(colors[foreground])), tuple(bytes.fromhex(colors['background'])))
        self.assertGreaterEqual(ratio, 4.5, f'{name} cover {foreground}: {ratio:.2f}:1')
    return test


for name in ('ocean', 'graphite', 'ivory', 'forest', 'sand', 'slate'):
    for foreground in ('foreground', 'muted'):
        setattr(CoverPairTests, f'test_{name}_{foreground}', cover_test(name, foreground))


if __name__ == '__main__':
    colors = palette()
    output = ROOT / 'docs/design/evidence/contrast-ratios.json'
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps([
        {'foreground': f, 'surface': s, 'minimum': minimum,
         'foregroundRGB': colors[f], 'surfaceRGB': colors[s],
         'ratio': contrast(colors[f], colors[s])}
        for f, s, minimum in PAIRS
    ], indent=2) + '\n')
    unittest.main(verbosity=2)
