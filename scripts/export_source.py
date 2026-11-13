#!/usr/bin/env python3
"""Export own source only; never include dependencies, keys, ROMs or builds."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import os, stat

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = Path(os.environ.get('SOURCE_ZIP',str(ROOT/'dist/MagicLite-source.zip')))
EXTENSIONS={'.java','.xml','.sh','.py','.md','.prop','.list','.yml','.yaml'}
ROOT_FILES=['README.md','LICENSE','.gitignore']

def source_files():
    result=[ROOT/name for name in ROOT_FILES]
    for directory in ['app','module','scripts','.github']:
        for file in (ROOT/directory).rglob('*'):
            if file.is_file() and file.suffix in EXTENSIONS and not any((p.startswith('.') and p != '.github') or p=='__pycache__' for p in file.relative_to(ROOT).parts):
                if file.is_symlink(): raise ValueError('Do not export symlinks: '+str(file.relative_to(ROOT)))
                result.append(file)
    for file in result:
        if file.is_symlink(): raise ValueError("Do not export symlinked root files: "+str(file.relative_to(ROOT)))
    return sorted(set(result))

def main():
    OUTPUT.parent.mkdir(parents=True,exist_ok=True)
    files=source_files()
    with ZipFile(OUTPUT,'w',compression=ZIP_DEFLATED) as archive:
        for file in files: archive.write(file,'MagicLite/'+str(file.relative_to(ROOT)))
    with ZipFile(OUTPUT) as archive:
        assert archive.testzip() is None
        assert len(archive.namelist())==len(files)
        assert not any(stat.S_ISLNK(i.external_attr>>16) for i in archive.infolist())
    print('Source archive:',OUTPUT)
    print('Source files:',len(files))
if __name__=='__main__': main()
