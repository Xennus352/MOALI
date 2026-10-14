#!/usr/bin/env python3
"""Resize assets/logos/app_icon.png into the platform launcher icon slots.

Requires ImageMagick (`magick`). Run from any directory with:
    python3 tool/generate_app_icons.py
"""

import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/logos/app_icon.png'


def png(destination, size, *, opaque=False, maskable=False):
    content_size = round(size * 0.8) if maskable else size
    command = ['magick', str(SOURCE), '-resize', f'{content_size}x{content_size}']
    if maskable:
        command += ['-background', 'white', '-gravity', 'center',
                    '-extent', f'{size}x{size}']
    if opaque:
        command += ['-background', 'white', '-alpha', 'remove', '-alpha', 'off']
    subprocess.run(command + [str(destination)], check=True)


for density, size in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96,
                      'xxhdpi': 144, 'xxxhdpi': 192}.items():
    png(ROOT / f'android/app/src/main/res/mipmap-{density}/ic_launcher.png', size)

for platform in ['ios', 'macos']:
    directory = ROOT / platform / 'Runner/Assets.xcassets/AppIcon.appiconset'
    manifest = json.loads((directory / 'Contents.json').read_text())
    for icon in manifest['images']:
        if 'filename' in icon:
            size = round(float(icon['size'].split('x')[0]) *
                         float(icon['scale'].removesuffix('x')))
            png(directory / icon['filename'], size, opaque=platform == 'ios')

for size in [192, 512]:
    png(ROOT / f'web/icons/Icon-{size}.png', size)
    png(ROOT / f'web/icons/Icon-maskable-{size}.png', size,
        opaque=True, maskable=True)
png(ROOT / 'web/favicon.png', 32)

subprocess.run(['magick', str(SOURCE), '-define',
                'icon:auto-resize=256,128,64,48,32,16',
                str(ROOT / 'windows/runner/resources/app_icon.ico')], check=True)
print('Generated Android, iOS, macOS, Windows and web icons from app_icon.png.')
