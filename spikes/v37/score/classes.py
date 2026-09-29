"""D outcome classes on an open run: gold coarse, predicted state, asks, check verdict, locator. Usage: classes.py LABEL [CONFIG]"""
import json, sys, collections
label = sys.argv[1]; config = sys.argv[2] if len(sys.argv) > 2 else 'D'
cases = {c['id']: c for c in json.load(open('spikes/v37/cases/p-dev.json'))['cases']}
s = json.load(open(f'spikes/v37/scores/{label}.score.json'))
recs = {json.loads(l)['caseID']: json.loads(l) for l in open(f'spikes/v37/readings/{label}.jsonl')}
def gold(c): return 'misconception' if c['misconceptions'] or c['state'] == 'misconception' else 'positive' if c['state'] in ('understood', 'mostlyUnderstood') else 'weak'
def coarse(st): return 'misconception' if st == 'misconception' else 'positive' if st in ('understood', 'mostlyUnderstood') else 'weak'
t = collections.Counter(); ex = collections.defaultdict(list)
for cid, p in s['perCase'][config].items():
    st, asks = p['signature'].split('|')[:2]
    r = recs[cid]; op = (r.get('secondOpinion') or {}).get('output') or {'items': [], 'verdicts': []}
    v = {x['item']: x['verdict'] for x in op['verdicts']}
    loc = [v[i['item']] for i in op['items'] if i['kind'] == 'locate']
    key = ('OK' if coarse(st) == gold(cases[cid]) else 'XX', gold(cases[cid]), cases[cid]['state'], st, 'ask' if asks == 'true' else 'commit', v.get(1, '-'), loc[0] if loc else '-')
    t[key] += 1; ex[key].append(cid)
for k, n in sorted(t.items(), key=lambda x: (x[0][0], -x[1])): print(n, k, ' '.join(ex[k][:6]))
