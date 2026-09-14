#!/usr/bin/env python3
"""Reject omissions, skips, duplicate execution, or retries in the complete native run."""
from pathlib import Path
import re
import sys
from qa_inventory import ROOT, expected_tests, native_batches


def verify(text, expected, marker):
    if text.count(marker) != 1:
        return [f'Missing or duplicated stage: {marker}']
    stage = text.split(marker, 1)[1].split('\n=== ', 1)[0]
    outcomes = re.findall(r"Test Case '-\[(?:\w+\.)?(\w+)\s+(test\w+)\]' (passed|failed|skipped)", stage)
    passed = {(s, m) for s, m, result in outcomes if result == 'passed'}
    seen = {}
    issues = [f'{s}.{m}: {result}' for s, m, result in outcomes if result != 'passed']
    issues += [f'Not recorded as passed: {s}.{m}' for s, m in sorted(expected - passed)]
    for suite, method, result in outcomes:
        seen.setdefault((suite, method), []).append(result)
    issues += [f'Unexpected test in this batch: {s}.{m}' for s, m in sorted(set(seen) - expected)]
    issues += [f'{s}.{m}: duplicate/retry sequence {results}' for (s, m), results in seen.items() if len(results) != 1]
    if '** TEST SUCCEEDED **' not in stage or '** TEST FAILED **' in stage:
        issues.append('Native stage did not complete successfully.')
    return issues


def verify_all(text, root=ROOT):
    issues = []
    for marker, _, expected in native_batches(root):
        issues += verify(text, expected, marker)
    return issues


def main():
    if len(sys.argv) != 2:
        print('Usage: verify-qa-results.py <complete-native-qa-log>', file=sys.stderr)
        return 2
    try:
        text = Path(sys.argv[1]).read_text(errors='replace')
        issues = verify_all(text)
    except (ValueError, OSError) as error:
        print('FAIL: Native inventory verification failed: ' + str(error))
        return 2
    if issues:
        print('FAIL: complete native coverage was not established.')
        print('\n'.join(' - ' + issue for issue in issues))
        return 1
    apple = expected_tests(ROOT / 'ShelfTests')
    ui = expected_tests(ROOT / 'ShelfUITests')
    print(f'PASS: all {len(apple)} Apple tests and all {len(ui)} unique UI tests passed exactly once across non-overlapping batches; no omissions, skips, duplicates or failure-retries accepted.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
