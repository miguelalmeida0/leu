"""Per-case view of an open development run (P or C only): gold, the model's labels, each config's decision.
Usage: diagnose.py SET LABEL [CONFIG] [--wrong]"""
import json, sys
S, label = sys.argv[1], sys.argv[2]
config = sys.argv[3] if len(sys.argv) > 3 and not sys.argv[3].startswith('--') else 'D'
wrong_only = '--wrong' in sys.argv
root = 'spikes/v37/'
cases = {c['id']: c for c in json.load(open(root + 'cases/' + {'P': 'p-dev', 'C': 'canonical'}[S] + '.json'))['cases']}
inputs = {c['caseID']: c for c in json.load(open(root + f'inputs/{S}.json'))['cases']}
recs = {json.loads(l)['caseID']: json.loads(l) for l in open(root + f'readings/{label}.jsonl')}
score = json.load(open(root + f'scores/{label}.score.json'))
per = score['perCase'][config]
def coarse(st, mis=False):
    return 'misconception' if mis or st == 'misconception' else 'positive' if st in ('understood', 'mostlyUnderstood') else 'weak'
for cid, c in cases.items():
    p = per.get(cid, {})
    ok = p.get('coarseRight')
    sig = (p.get('signature') or '|||').split('|')
    p = dict(p, state=sig[0], asks=sig[1])
    if wrong_only and ok: continue
    inp = inputs[cid]; alias = {cl['id']: cl['alias'] + ('*' if cl['role'] == 'core' else '') for cl in inp['claims']}
    print(f"{'OK ' if ok else 'XX '}{cid} gold={c['state']}/{coarse(c['state'], bool(c['misconceptions']))} {config}={p.get('state')} asks={p.get('asks')} cats={','.join(c['categories'])}")
    print('    claims:', ' | '.join(f"{alias[cl['id']]} {cl['kind']}: {cl['text'][:70]}" for cl in inp['claims']))
    r = recs.get(cid, {}); o = (r.get('reading') or {}).get('output') or {}
    labels = {s['n']: s for s in o.get('segments', [])}
    for s in inp['segments']:
        l = labels.get(s['n'], {})
        print(f"    {s['n']}. {s['text'][:110]}\n         -> {l.get('role')} {alias.get(l.get('claim'), l.get('claim'))} {l.get('relation')} {l.get('polarity')} mis={l.get('misconception')} {l.get('describes')} {l.get('confidence')}")
    print('    links', [(x['reason'], x['conclusion']) for x in o.get('links', []) if x['reason'] != x['conclusion']],
          '2nd', [v['verdict'] for v in ((r.get('secondOpinion') or {}).get('output') or {}).get('verdicts', [])],
          'notes:', c.get('notes', '')[:120])
