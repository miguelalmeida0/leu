#!/usr/bin/env python3
"""Field-by-field evidence comparison; missing iOS/model data is never a PASS."""
import argparse
import json
from pathlib import Path

def read_events(path):
    events = []
    seen = set()
    for line in path.read_text().splitlines():
        start = line.find('{')
        if start < 0:
            continue
        try:
            event = json.loads(line[start:])
        except ValueError:
            continue
        if isinstance(event, dict) and 'event' in event:
            identity = json.dumps(event, sort_keys=True)
            if identity not in seen:
                events.append(event)
                seen.add(identity)
    return events

def difference(left, right, prefix=''):
    if isinstance(left, dict) and isinstance(right, dict):
        rows = []
        for key in sorted(set(left) | set(right)):
            path = prefix + '.' + key if prefix else key
            if key not in left or key not in right:
                rows.append({'field': path, 'mac': left.get(key, '<absent>'), 'ios': right.get(key, '<absent>')})
            else:
                rows.extend(difference(left[key], right[key], path))
        return rows
    if isinstance(left, list) and isinstance(right, list):
        rows = []
        for index in range(max(len(left), len(right))):
            path = prefix + '[' + str(index) + ']'
            if index >= len(left) or index >= len(right):
                rows.append({'field': path, 'mac': left[index] if index < len(left) else '<absent>',
                             'ios': right[index] if index < len(right) else '<absent>'})
            else:
                rows.extend(difference(left[index], right[index], path))
        return rows
    if left != right:
        return [{'field': prefix, 'mac': left, 'ios': right}]
    return []

def source_projection(record):
    packet = record['packet']
    return {'documentID': packet['documentID'], 'page': packet['pageIndex'] + 1,
            'fingerprint': packet['fingerprint'], 'sourceRange': packet['sourceRange'],
            'sourceSpans': packet['spans'], 'language': packet['language'],
            'extractionVersion': packet['extractionVersion'], 'promptVersion': record['schemaVersion']}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mac-record', type=Path, required=True)
    parser.add_argument('--mac-validation', type=Path, required=True)
    parser.add_argument('--ios-trace', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    mac = json.loads(args.mac_record.read_text())
    events = read_events(args.ios_trace)
    attempts = [e for e in events if e['event'] == 'EXPLANATION_ATTEMPT']
    results = []
    for attempt in attempts:
        batch = [e for e in events if e.get('requestID') == attempt['requestID'] and e.get('attempt') == attempt['attempt']]
        raw = next((e for e in batch if e['event'] == 'MODEL_RESULT'), None)
        validation = next((e for e in batch if e['event'] == 'VALIDATION_RESULT'), None)
        source = source_projection(mac)
        source_diff = difference(source, {key: attempt.get(key, '<absent>') for key in source})
        candidate = raw.get('rawStructuredFields') if raw else None
        decoded = next((e for e in batch if e['event'] == 'MODEL_RESULT_DECODED'), None)
        results.append({'mode': attempt['mode'], 'requestID': attempt['requestID'], 'attempt': attempt['attempt'],
            'sourceMatchesMac': not source_diff, 'sourceDifferences': source_diff,
            'iosCandidate': candidate, 'iosValidation': validation,
            'candidateDifferences': difference(mac['candidate'], candidate) if candidate is not None else None,
            'latencyMilliseconds': decoded.get('latencyMilliseconds') if decoded else None,
            'repairEvents': [e for e in batch if e['event'] == 'REPAIR'],
            'finalStates': [e for e in batch if e['event'] == 'FINAL_STATE']})
    output = {'macCandidate': mac['candidate'], 'macValidation': json.loads(args.mac_validation.read_text()),
        'iosAttempts': results, 'iosEvidence': 'PRESENT' if results else 'MISSING',
        'warning': 'Field equality and deterministic validation do not grade semantic correctness.'}
    args.output.write_text(json.dumps(output, indent=2, ensure_ascii=False) + '\n')
    print('iOS attempts compared:', len(results))
    return 0 if results else 2

if __name__ == '__main__':
    raise SystemExit(main())
