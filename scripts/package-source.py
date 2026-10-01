"""Create an Aura source handoff without runtime data, local toolchains or signing keys."""
from pathlib import Path
import os, zipfile
root = Path(__file__).resolve().parent.parent
output = root / 'Aura-local-pilot.zip'
excluded = {'.git', '.toolchains', '.build', '.gradle', 'node_modules', 'dist', 'data',
            'build', 'DerivedData', 'xcuserdata', 'test-results', 'playwright-report', 'artifacts', '__pycache__'}
with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
    for folder, directories, files in os.walk(root):
        directories[:] = sorted(d for d in directories if d not in excluded and not (Path(folder) / d).is_symlink())
        for name in sorted(files):
            path = Path(folder) / name
            if path == output or path.is_symlink() or name in {'.DS_Store', 'local.properties', '.env'}: continue
            if name.startswith('.env.') or name.endswith(('.log', '.jks', '.keystore', '.xcuserstate', '.sqlite', '.sqlite-wal', '.sqlite-shm')): continue
            archive.write(path, Path('Aura') / path.relative_to(root))
with zipfile.ZipFile(output) as archive:
    assert archive.testzip() is None
    print(f'{output}: {len(archive.namelist())} files, {output.stat().st_size} bytes')
