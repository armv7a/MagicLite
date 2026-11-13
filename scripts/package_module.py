#!/usr/bin/env python3
from pathlib import Path
from zipfile import ZipFile, ZipInfo, ZIP_STORED, ZIP_DEFLATED
import argparse
import hashlib
import stat
import subprocess

ROOT = Path(__file__).resolve().parents[1]
FILES = ['customize.sh', 'post-fs-data.sh', 'service.sh', 'app-install.sh', 'uninstall.sh', 'cleanup-apk.sh']


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--apk', required=True, type=Path)
    parser.add_argument('--module-prop', required=True, type=Path)
    args = parser.parse_args()
    subprocess.run(['apksigner', 'verify', str(args.apk)], check=True)
    for name in FILES:
        subprocess.run(['sh', '-n', str(ROOT / 'module' / name)], check=True)
    data = {name: (ROOT / 'module' / name).read_bytes() for name in FILES}
    data['module.prop'] = args.module_prop.read_bytes()
    data['LICENSE'] = (ROOT / 'LICENSE').read_bytes()
    data['payload/LiteFix.apk'] = args.apk.read_bytes()
    data['payload/LiteFix.apk.sha256'] = (hashlib.sha256(data['payload/LiteFix.apk']).hexdigest() + '  payload/LiteFix.apk\n').encode()
    output = args.apk.with_suffix('.zip')
    with ZipFile(output, 'w') as archive:
        for name, content in data.items():
            info = ZipInfo(name, date_time=(2026, 11, 13, 0, 0, 0))
            info.create_system = 3
            info.external_attr = (stat.S_IFREG | (0o755 if name.endswith('.sh') else 0o644)) << 16
            info.compress_type = ZIP_STORED if name.endswith('.apk') else ZIP_DEFLATED
            archive.writestr(info, content)
    with ZipFile(output) as archive:
        assert archive.testzip() is None
        assert set(archive.namelist()) == set(data)
        assert archive.read('payload/LiteFix.apk') == args.apk.read_bytes()
    print('Module:', output)
    print('SHA256:', hashlib.sha256(output.read_bytes()).hexdigest())


if __name__ == '__main__':
    main()
