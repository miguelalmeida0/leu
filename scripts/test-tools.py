#!/usr/bin/env python3
from pathlib import Path
import subprocess, tempfile, json, os, hashlib, uuid, struct, sys
R=Path(__file__).resolve().parents[1]
results=[]
def run(args, **kwargs):return subprocess.run(args, capture_output=True,text=True,**kwargs)
with tempfile.TemporaryDirectory() as directory:
 p=Path(directory)
 inventory={'devices':{
 'com.apple.CoreSimulator.SimRuntime.iOS-16-4':[{'name':'iPhone 14','udid':'old','state':'Booted','isAvailable':True}],
 'com.apple.CoreSimulator.SimRuntime.iOS-18-3':[{'name':'iPhone 16','udid':'booted','state':'Booted','isAvailable':True}],
 'com.apple.CoreSimulator.SimRuntime.iOS-26-0':[{'name':'iPhone 17','udid':'latest','state':'Shutdown','isAvailable':True},{'name':'iPad Pro','udid':'ipad','state':'Booted','isAvailable':True}],
 'com.apple.CoreSimulator.SimRuntime.tvOS-26-0':[{'name':'Apple TV','udid':'tv','state':'Booted','isAvailable':True}]}}
 f=p/'devices.json';f.write_text(json.dumps(inventory))
 command=['swift',str(R/'scripts/choose-simulator.swift'),str(f)]
 r=run(command);assert r.returncode==0 and r.stdout.strip()=='booted',r.stderr;results.append('simulator: prefers compatible booted iPhone')
 env={**os.environ,'SHELF_SIMULATOR_UDID':'latest'}
 r=run(command,env=env);assert r.returncode==0 and r.stdout.strip()=='latest',r.stderr;results.append('simulator: accepts available override')
 r=run(command,env={**os.environ,'SHELF_SIMULATOR_UDID':'old'});assert r.returncode!=0;results.append('simulator: rejects unsupported iOS override')
 inventory['devices']['com.apple.CoreSimulator.SimRuntime.iOS-18-3'][0]['state']='Shutdown';f.write_text(json.dumps(inventory))
 r=run(command);assert r.returncode==0 and r.stdout.strip()=='latest',r.stderr;results.append('simulator: prefers newest iOS when none booted')
 f.write_text('{bad json');assert run(command).returncode!=0;results.append('simulator: reports damaged inventory')
 # Archive fixture follows the actual Swift Codable shape; cross-language fixture tested separately.
 data=(R/'Shelf/Resources/Samples/React Notes.pdf').read_bytes();identifier=str(uuid.uuid4()).upper();digest=hashlib.sha256(data).hexdigest()
 manifest={'version':1,'exportedAt':0,'library':{'schemaVersion':1,'books':[{'id':identifier,'title':'React Notes','byteCount':len(data),'fingerprint':digest}],'annotations':[]},'originals':[{'id':identifier,'size':len(data),'fingerprint':digest}]}
 encoded=json.dumps(manifest).encode();blob=b'SHELF-BACKUP\n1\n'+struct.pack('<Q',len(encoded))+encoded+data
 source=p/'good.shelfbackup';source.write_bytes(blob);dest=p/'recovered'
 base=[sys.executable,str(R/'scripts/unpack-backup.py')]
 r=run(base+[str(source),str(dest)]);assert r.returncode==0,r.stderr;assert (dest/'Originals'/f'{identifier}.pdf').read_bytes()==data;results.append('extractor: byte-identical originals and metadata')
 assert run(base+[str(source),str(dest)]).returncode!=0;results.append('extractor: refuses existing destination')
 for name,damaged in [('truncated',blob[:-4]),('tampered',blob[:-1]+bytes([blob[-1]^1])),('trailing',blob+b'x'),('bad-magic',b'Q'+blob[1:])]:
  src=p/(name+'.shelfbackup');src.write_bytes(damaged);out=p/name
  r=run(base+[str(src),str(out)]);assert r.returncode!=0 and not out.exists(),(name,r.stdout,r.stderr)
  results.append('extractor: rejects '+name+' with no committed output')
 assert not list(p.glob('.shelf-extract-*'));results.append('extractor: failure staging cleaned up')
 for path in [R/'run.sh', *R.glob('scripts/*.sh'),R/'scripts/dev/Start Leu.command']:
  assert run(['bash','-n',str(path)]).returncode==0,path
 results.append('launcher: shell syntax validated')
 r=run([str(R/'run.sh'),'--help']);assert r.returncode==0;results.append('launcher: help works without Xcode')
 r=run([str(R/'run.sh')]);assert r.returncode==1 and 'macOS' in r.stderr;results.append('launcher: actionable non-macOS prerequisite error')
print('\n'.join('PASS: '+r for r in results))
(R/'docs/internal/evidence/delivery-tools.log').write_text('\n'.join('PASS: '+r for r in results)+'\n')
(R/'docs/internal/evidence/delivery-tools.json').write_text(json.dumps({'passed':len(results),'checks':results,'nativeLaunchExecuted':False},indent=2)+'\n')
