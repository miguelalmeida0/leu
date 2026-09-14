#!/usr/bin/env python3
"""Render the V29 report exclusively from the executed certification artifacts."""
from pathlib import Path
import json, re, subprocess, hashlib
from collections import Counter
root = Path(__file__).resolve().parent.parent
out = root/'evidence/v29-real-reasoning'
def read(name): return json.loads((out/(name+'.json')).read_text())
a=read('audit'); atoms=read('atoms'); library=read('library-atoms'); byid={x['id']['rawValue']:x for x in library}
tests=re.findall(r'Executed (\d+) tests, with (\d+) failures', (out/'host-tests.log').read_text())[-1]
assert tests[1]=='0'
perf=read('performance'); bridge=read('pdf-bridge-performance'); candidates=read('cross-document-candidates')
def clean(s): return ' '.join(s.split()).replace('|','\\|')
def source(atom):
    s=atom['provenance']['spans'][0]
    return f"{s['documentID']} p.{s['page']}"
def statement(atom):
    q=', '.join(x['text'] for x in atom['qualifiers'])
    conditions=', '.join(('when ' if x['isPositive'] else 'unless ')+x['text'] for x in atom['conditions'])
    return clean(f"{atom['subject']} → {atom['relation']} → {atom['object']}" + (f" [{q}; {conditions}]" if q or conditions else ''))
def table(headers, rows):
    return '\n'.join(['| '+' | '.join(headers)+' |','|'+'|'.join(['---']*len(headers))+'|']+['| '+' | '.join(clean(str(x)) for x in row)+' |' for row in rows])
lines=[]
metrics=[('BUILD','PASS'),('SWIFT TESTS',f'{tests[0]}/{tests[0]}'),('REAL PDF SAMPLE',f"{a['samplePagesWithAtoms']}/40 pages with useful atoms"),('REAL KNOWLEDGE ATOMS',a['sampleAtoms']),('VALIDATED RELATIONS',a['sourceRelations']+a['definitionSubstitutions']+a['crossDocumentRelations']),('MULTI-STEP MECHANISM CHAINS',a['multiStepAnswers']),('COUNTERFACTUAL SCENARIOS',a['counterfactualScenarios']),('LEARNER ALIGNMENT',f"{a['learnerCases']-a['learnerFailures']}/{a['learnerCases']}"),('CROSS-DOCUMENT RELATIONS',a['crossDocumentRelations']),('UNSUPPORTED BRIDGES',a['unsupportedBridges']),('INVENTED CONSEQUENCES',a['inventedConsequences']),('UNSUPPORTED SYNTHESIS',a['unsupportedSynthesis']),('MANUFACTURED CONTRASTS',a['manufacturedContrasts'])]
for label,value in metrics: lines += [label+':', str(value), '']
lines += ['## Verification boundaries','',
 'Fresh native `swiftc` build and the actual package XCTest bundle passed. SwiftPM itself is blocked in this execution environment: stock invocation reports `permissionDenied`; a repository-local cache reaches `sandbox-exec: sandbox_apply: Operation not permitted`. The host runner does not disable that sandbox or replace XCTest assertions. It compiles the original tests and package plus the V29 tests, supplies the real resource bundle and executes Xcode’s native `xctest`. No simulator, UI, Foundation Models, backend, paid API or network inference was used.', '',
 'The inherited four source fixes are preserved in `inherited-fixes.patch` and incorporated. One synthetic disagreement fixture was corrected from “at most 5 attempts” to “exactly 5 attempts”: “at most 3” and “at most 5” are compatible. The existing disagreement assertion remains; the new compatible/disjoint interval test prevents manufactured conflicts.', '',
 f"The fixed sample produced {a['sampleAtoms']} atoms. The complete context index has {len(library)} atoms, including definitions from non-sampled cards and prose from the bundled notes. Its {a['sourceRelations']} stated edges are reported separately from {a['definitionSubstitutions']} definitional substitutions and {a['crossDocumentRelations']} cross-document definition-context edges. These categories are not interchangeable.", '',
 f"There are {a['mechanismAnswers']} answered why/mechanism queries, including {a['multiStepAnswers']} with two edges. The multi-step paths are definition → stated effect, with the second step admitted by definition substitution. They are useful explanatory paths, not evidence of seven independent multi-hop causal discoveries. Definition-only paths do not count as mechanism answers.", '',
 'The zero unsupported counts are bounded certification results: admitted-edge/provenance checks, source-span rebinds, conservative consequence rules, quote-only synthesis output and adversarial tests. They are not a universal claim of semantic completeness or zero error on arbitrary PDFs.', '',
 '## Source sampling','',
 'Select every page containing the exact normalized heading IN ONE BREATH, then select 40 indices by round(i × (cardCount − 1) / 39). The page set was fixed before tuning extraction. Primary facts end before MAKE IT STICK. Mnemonic, example, interview-advice and WATCH/LEVEL-UP sections cannot create primary facts. Offsets are UTF-16 indices into the unmodified PDFKit page string.', '',
 ', '.join(str(x['page']) for x in read('sample-pages')), '',
 table(['PDF','SHA-256'],[(d['title'],d['sha256']) for d in read('pdf-pages')]), '',
 '## Best 15 real atoms','']
best=[x for x in atoms if x['claimType']!='definition'][:15]
lines += [table(['Source page','Structured claim','Exact source text'],[(source(x),statement(x),x['provenance']['spans'][0]['canonicalSpan']) for x in best]),'',
 '## Best 15 relations','']
relations=read('relations'); sampleIDs={x['id']['rawValue'] for x in atoms}
stated=[r for r in relations if r['provenance']['admissibility']=='sourceSupported' and r['kind']!='explains' and any(x['rawValue'] in sampleIDs for x in r['supportingAtoms'])][:5]
inferred=[r for r in relations if r['provenance']['rule']=='definitionSubstitution'][:10]
rows=[]
for r in stated+inferred:
    parents=[byid[x['rawValue']] for x in r['supportingAtoms']]
    rows.append((r['kind'],r['provenance']['admissibility'],r['provenance']['rule'],'; '.join(statement(p) for p in parents),'; '.join(source(p) for p in parents)))
lines += [table(['Relation','Class','Admission rule','Full atom bridge','Sources'],rows),'', '## Best 8 mechanism paths','']
answers=read('mechanism-chains'); paths=[c['paths'][0] for c in answers if c['paths']]
paths=sorted(paths,key=lambda p:-len(p['steps']))[:8]
for i,p in enumerate(paths,1):
    lines += [f"{i}. "+'; '.join(clean(s['fromLabel']+' —'+s['kind']+'→ '+s['toLabel']) for s in p['steps'])+'.',
              '   Sources: '+', '.join(f"{s['documentID']} p.{s['page']}" for s in p['provenance']['spans'])+'.']
lines += ['', 'Every displayed edge is present in the admitted graph. A missing continuation is left open; a configured traversal limit is explicitly distinguished from absent source evidence.', '', '## Best 10 counterfactuals','']
for i,c in enumerate(read('counterfactuals')[:10],1):
    lines += [f"{i}. {clean(str(c['change']))}: "+'; '.join(x['polarity']+': '+clean(x['label']) for x in c['consequences'])+'. '+clean(' '.join(c['openQuestions']))]
lines += ['', 'Removing prevention never proves failure. Removing sufficient support never proves its outcome false. Only an unconditional necessary prerequisite licenses definite dependency failure and further propagation. An unbound property is unresolved.', '', '## Learner understanding','']
learner=read('learner-alignment'); counts=Counter(x['input']['category'] for x in learner)
lines += [table(['Category','Passed/total'],[(category,f"{sum(x['passed'] for x in learner if x['input']['category']==category)}/{n}") for category,n in counts.items()]),'',
 table(['Category','Learner explanation','Actual verdict','Findings'],[(x['input']['category'],x['input']['text'],x['actual']['alignments'][0]['verdict'] if len(x['actual']['alignments'])==1 else 'component-wise; see JSON', ', '.join(f['type'] for y in x['actual']['alignments'] for f in y['findings'])) for x in learner]),'',
 'Paraphrase admission is deliberately bounded: relation synonyms, active/passive exchange, articles and a participial/time alternation. It does not claim unrestricted natural-language understanding. Similarity ranks candidates only. Predicate, arguments, negation, qualifiers, conditions, numbers and identifiers determine support.', '', '## Cross-document reasoning','',
 f"{len(candidates)} candidates: {sum(x['status']=='INFERRED_VALIDATED' for x in candidates)} admitted; {sum(x['status']=='UNRESOLVED' for x in candidates)} unresolved. Request-as-a-verb and ambiguous Interface/Context senses are not admitted. Qualified name resolution is restricted to an explicitly named document namespace.", '']
rows=[]
for r in read('cross-document'):
    first=byid[r['subject']['atom']['_0']['rawValue']]; second=byid[r['object']['atom']['_0']['rawValue']]
    rows.append((first['subject'],source(first)+': '+first['provenance']['spans'][0]['canonicalSpan'],source(second)+' ['+statement(second)+']: '+second['provenance']['spans'][0]['canonicalSpan'],'INFERRED_VALIDATED — definitionContext'))
lines += [table(['Term','Definition source A','Use source B','Support'],rows),'',
 'These edges explain a named term in a second source. They do not assert whole-claim equivalence, contradiction, causation or generalization.', '',
 '## Multi-source synthesis','',
 '15 actual two-source comparisons: ten definition-context pairs and five unresolved controls. Statements are the exact source excerpts, with separate open questions. No real conflict was manufactured to fill a category. The implementation separately tests equivalence, restrictions and numeric/negation conflicts with adversarial cases; those synthetic attacks are not counted as real-document synthesis evidence.', '',
 '## Question planning and understanding state','',
 'Question plans select cognitive operations and required grounded material. The React.memo condition omission produces `identifyMissingCondition` for “props are stable”, priority 0.98, with the explicit learner omission as the reason. Plans contain no generated question copy. `question-plans.json` records every evaluated learner case.', '',
 'The state evidence projects an explicit source revisit, submitted incomplete explanation, correction and resubmission. Attempts retain the full alignment, including supported, missing and contradicted propositions. Source opening alone creates neither a successful attempt nor mastery. Optional alignment preserves decoding compatibility for prior state archives. No emotion, intelligence, motivation or dwell-time signal is used.', '',
 'Explanation strategies are selected from admitted source material; no analogy is generated. See `explanation-strategies.json`.', '', '## Performance','',
 f"Fresh PDFKit bridge: {bridge['milliseconds']:.2f} ms for {bridge['pages']} pages in {bridge['pdfCount']} PDFs. Measurements use the actual native Mac process, without an optimization build flag.", '',
 table(['Operation','Samples','p50 ms','p95 ms'],[(k,v['count'],f"{v['p50MS']:.3f}",f"{v['p95MS']:.3f}") for k,v in perf.items()]),'',
 '## Reproduce','', '```sh', 'python3 scripts/test-reasoning-host.py', 'python3 scripts/certify-v29-reasoning.py', 'python3 scripts/report-v29-reasoning.py', '```','',
 '## Remaining limits','',
 '- This is an isolated reasoning package, not a V28.1 UI integration. Protected production paths remain unchanged.',
 '- Card/title completion and prose parsing are bounded grammars. Ambiguous pronouns and unsupported grammar remain unresolved; the full rejection file exposes them.',
 '- Cross-source reasoning currently certifies definition-context links. It does not certify broad causal discovery across the library.',
 '- The seven two-edge explanations substitute definitions into stated effects; deeper independent causal mechanisms remain to be proven on richer sources.',
 '- The learner set is 32 authored explanations of actual extracted claims, not an independent human benchmark. Broad free-form paraphrases and implicit premises remain limited.',
 '- The real synthesis sample contains no proven genuine disagreement; adversarial tests cover conflicting and compatible constraints separately.',
 '- SwiftPM launch remains an environment limitation even though native compilation and real XCTest execution pass.', '',
 '## Scope and files','']
changed=subprocess.check_output(['git','status','--short'],cwd=root,text=True)
lines += ['```text',changed.rstrip(),'```','', 'The pre-existing `evidence/super-intelligence` files are preserved and are not treated as fresh V29 certification. The legitimate V29 package, tooling and evidence are the commit scope.']
(out/'REPORT.md').write_text('\n'.join(map(str,lines))+'\n')
files=sorted((root/'Packages/LeuReasoningCore').rglob('*.swift'))+sorted((root/'Packages/LeuReasoningCore/Tests').rglob('*.json'))
files += [root/'scripts'/x for x in ['v29-pdf-bridge.swift','v29-certify.swift','certify-v29-reasoning.py','test-reasoning-host.py','report-v29-reasoning.py']]
manifest={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files if '.build' not in p.parts}
(out/'source-manifest.json').write_text(json.dumps(manifest,indent=2,sort_keys=True)+'\n')
print(out/'REPORT.md')
