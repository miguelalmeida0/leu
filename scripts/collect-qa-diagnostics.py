#!/usr/bin/env python3
"""Export this QA run's native attachments and opt-in action traces; never rerun tests."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile


def command(args: list[str], timeout: int = 60) -> tuple[int, str]:
    try:
        completed = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
        return completed.returncode, completed.stdout + completed.stderr
    except (OSError, subprocess.TimeoutExpired) as error:
        return 1, str(error)


def unique_lines(path: Path) -> list[str]:
    return list(dict.fromkeys(path.read_text().splitlines())) if path.is_file() else []


def collect(root: Path, run: Path, log: Path, qa_status: int) -> Path:
    output = run / 'artifacts'
    output.mkdir(parents=True, exist_ok=True)
    notes: list[str] = []
    epoch = run / 'start-epoch.txt'
    started = float(epoch.read_text().strip()) if epoch.exists() else run.stat().st_ctime
    if log.is_file():
        shutil.copy2(log, output / 'qa-full.log')
    manifest = root / 'SOURCE_SHA256SUMS.txt'
    metadata = {
        'version': '24.5', 'qaExitCode': qa_status, 'workspace': str(root),
        'sourceManifestSHA256': hashlib.sha256(manifest.read_bytes()).hexdigest() if manifest.exists() else None,
        'nativeResults': unique_lines(run / 'native-results.txt'),
        'devices': unique_lines(run / 'native-devices.txt'),
        'disclaimer': 'Local QA data only. No test was rerun by this collector.'
    }
    for name in ['native-results.txt', 'native-devices.txt', 'native-commands.txt',
                 'suite-plan.json', 'suite-results.json', 'coverage-check.txt']:
        source = run / name
        if source.is_file():
            shutil.copy2(source, output / name)
    if sys.platform == 'darwin':
        code, text = command(['xcodebuild', '-version'])
        (output / 'xcode-version.txt').write_text(text)
        for index, name in enumerate(metadata['nativeResults']):
            result = Path(name)
            if not result.is_dir():
                notes.append(f'Native result missing: {result}')
                continue
            folder = output / f'native-{index + 1}'
            folder.mkdir(exist_ok=True)
            code, text = command(['xcrun', 'xcresulttool', 'get', 'test-results', 'summary', '--path', str(result)])
            try:
                json.loads(text)
                summary_name = 'summary.json' if code == 0 else 'summary-export-error.txt'
            except ValueError:
                summary_name = 'summary-export-output.txt'
            (folder / summary_name).write_text(text)
            # Both successful checkpoints and failure screenshots are useful for the tap boundary.
            code, text = command(['xcrun', 'xcresulttool', 'export', 'attachments',
                                  '--path', str(result), '--output-path', str(folder / 'attachments')], timeout=120)
            if code:
                notes.append(f'Attachment export failed for {result.name}; original .xcresult remains available.')
                (folder / 'attachment-export-error.txt').write_text(text)
        for index, device in enumerate(metadata['devices']):
            code, text = command(['xcrun', 'simctl', 'get_app_container', device, 'dev.shelf.personal', 'data'])
            data = Path(text.strip())
            traces = data / 'tmp' / 'LeuUIDiagnostics'
            if code == 0 and traces.is_dir():
                destination = output / f'device-{index + 1}-action-traces'
                destination.mkdir(exist_ok=True)
                count = 0
                for path in traces.glob('study-*.jsonl'):
                    if path.stat().st_mtime < started:
                        continue
                    current = []
                    for line in path.read_text(errors='replace').splitlines():
                        try:
                            if float(json.loads(line).get('timestamp', 0)) >= started:
                                current.append(line)
                        except (ValueError, TypeError):
                            notes.append(f'Unreadable trace record in {path.name}.')
                    if current:
                        (destination / path.name).write_text('\n'.join(current) + '\n')
                        count += len(current)
                if not count:
                    notes.append(f'No action trace records for this run on {device}; activation remains unverified.')
            else:
                notes.append(f'No action traces exported for {device}; this does not establish whether activation occurred.')
    else:
        notes.append('Apple native exports unavailable on this operating system.')
    metadata['exportNotes'] = notes
    (output / 'manifest.json').write_text(json.dumps(metadata, indent=2) + '\n')
    bundle = root / f'Leu-QA-Diagnostics-{run.name}.zip'
    with zipfile.ZipFile(bundle, 'w', zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(output.rglob('*')):
            if path.is_file() and not path.is_symlink():
                archive.write(path, str(path.relative_to(output)))
    print(f'Diagnostics bundle: {bundle}')
    for note in notes:
        print(f'Diagnostics note: {note}')
    return bundle


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--run-dir', type=Path, required=True)
    parser.add_argument('--log', type=Path, required=True)
    parser.add_argument('--qa-status', type=int, required=True)
    args = parser.parse_args()
    collect(args.root.resolve(), args.run_dir.resolve(), args.log.resolve(), args.qa_status)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
