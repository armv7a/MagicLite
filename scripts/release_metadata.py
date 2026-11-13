#!/usr/bin/env python3
"""Stamp release copies without changing the checked-in version templates."""
import argparse
import re
import shlex
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ANDROID = 'http://schemas.android.com/apk/res/android'


def release_info(tag, commit):
    match = re.fullmatch(r'v?(0|[1-9][0-9]*)(?:[.](0|[1-9][0-9]*))?(?:[.](0|[1-9][0-9]*))?', tag)
    if not match:
        raise ValueError('Use a numeric tag such as v1, v1.2 or v1.2.3')
    major, minor, patch = (int(part or 0) for part in match.groups())
    code = major * 1_000_000 + minor * 1_000 + patch
    if minor > 999 or patch > 999 or not 1 <= code <= 2_100_000_000:
        raise ValueError('Tag is outside the Android versionCode range')
    if not re.fullmatch(r'[0-9a-fA-F]{40}', commit):
        raise ValueError('COMMIT_SHA must be the full Git commit SHA')
    return tag, code, 'MagicLite-' + tag + '(' + commit[:7].lower() + ')'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tag', required=True)
    parser.add_argument('--commit', required=True)
    parser.add_argument('--output-dir', required=True, type=Path)
    args = parser.parse_args()
    try:
        version, code, artifact = release_info(args.tag, args.commit)
    except ValueError as error:
        parser.error(str(error))
    ET.register_namespace('android', ANDROID)
    manifest = ET.parse(ROOT / 'app/src/main/AndroidManifest.xml')
    manifest.getroot().set('{' + ANDROID + '}versionName', version)
    manifest.getroot().set('{' + ANDROID + '}versionCode', str(code))
    props = (ROOT / 'module/module.prop').read_text()
    for key, value in [('version', version), ('versionCode', str(code))]:
        props, count = re.subn(r'^' + key + r'=.*$', key + '=' + value, props, flags=re.MULTILINE)
        if count != 1:
            raise ValueError('Expected exactly one ' + key + ' in module.prop')
    args.output_dir.mkdir(parents=True, exist_ok=True)
    manifest.write(args.output_dir / 'AndroidManifest.xml', encoding='utf-8', xml_declaration=True)
    (args.output_dir / 'module.prop').write_text(props)
    for key, value in [('VERSION_NAME', version), ('VERSION_CODE', str(code)), ('ARTIFACT_NAME', artifact)]:
        print(key + '=' + shlex.quote(value))


if __name__ == '__main__':
    main()
