#!/usr/bin/env python3
"""Run every independent suite once after a successful build; preserve the first failure."""
from __future__ import annotations
from pathlib import Path
import json
import os
import subprocess
import sys
from qa_inventory import ROOT, native_batches


def plan(root: Path):
    commands = [('=== Leu portable core tests ===', [str(root / 'scripts/test-core.sh')])]
    for marker, target, tests in native_batches(root):
        args = [str(root / 'scripts/test-ios.sh')]
        args += ['-only-testing:' + target + '/' + suite + '/' + name for suite, name in sorted(tests)]
        commands.append((marker, args))
    return commands


def run(root: Path = ROOT, run_dir: Path | None = None) -> int:
    commands = plan(root)  # Reject incomplete inventories before starting any tests.
    records = []
    if run_dir:
        run_dir.mkdir(parents=True, exist_ok=True)
        (run_dir / 'suite-plan.json').write_text(json.dumps(commands, indent=2) + '\n')
    first_failure = 0
    for marker, args in commands:
        print('\n' + marker, flush=True)
        try:
            code = subprocess.run(args, cwd=root, check=False).returncode
            if code < 0:
                code = 128 - code
        except OSError as error:
            print('FAIL: Cannot execute suite: ' + str(error), flush=True)
            code = 127
        except KeyboardInterrupt:
            print('FAIL: QA was interrupted; unexecuted tests are not passed.', flush=True)
            return 130
        records.append({'stage': marker, 'exitCode': code, 'command': args})
        if run_dir:
            (run_dir / 'suite-results.json').write_text(json.dumps(records, indent=2) + '\n')
        print(f'QA_STAGE_RESULT: {marker.strip("= ")} | exit code {code}', flush=True)
        if code != 0:
            first_failure = first_failure or code
            print('FAIL: Stage recorded; continuing independent suites to collect the full failure set.', flush=True)
    print('\nQA complete. Every planned suite was attempted once; failures above remain failures.', flush=True)
    return first_failure


if __name__ == '__main__':
    try:
        value = os.environ.get('SHELF_QA_RUN_DIR')
        raise SystemExit(run(run_dir=Path(value) if value else None))
    except (ValueError, OSError) as error:
        print('FAIL: QA inventory could not be established: ' + str(error), file=sys.stderr)
        raise SystemExit(2)
