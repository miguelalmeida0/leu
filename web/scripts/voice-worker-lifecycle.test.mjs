import test from 'node:test'
import assert from 'node:assert/strict'
import {readFile} from 'node:fs/promises'
import vm from 'node:vm'
import ts from 'typescript'

const deferred=()=>{let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b});return {promise,resolve,reject}}
async function fixture({slowLoad=false,slowGenerate=false,slowDispose=false}={}) {
  const load=deferred(),generation=deferred(),disposal=deferred(),messages=[],events=[]
  const model={model:{dispose:async()=>{events.push('dispose');if(slowDispose)await disposal.promise;events.push('disposed')}},
    generate:async()=>{events.push('generate');if(slowGenerate)await generation.promise;events.push('generated');return {audio:new Float32Array([.2,.3]),sampling_rate:24000}}}
  const context=vm.createContext({console,Float32Array,performance,navigator:{},self:{},postMessage:m=>messages.push(m)})
  const code=ts.transpileModule(await readFile(new URL('../src/lib/voice.worker.ts',import.meta.url),'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ESNext}}).outputText
  const module=new vm.SourceTextModule(code,{context})
  await module.link(()=>new vm.SyntheticModule(['KokoroTTS'],function(){this.setExport('KokoroTTS',{from_pretrained:async()=>{events.push('load');return slowLoad?load.promise:model}})},{context}))
  await module.evaluate()
  const send=data=>context.self.onmessage({data})
  const settle=async()=>{for(let i=0;i<30;i++)await Promise.resolve()}
  return {send,settle,load,generation,disposal,messages,events,model}
}
test('disposal during cold prefetch prevents late synthesis and releases the loaded model',async()=>{
  const f=await fixture({slowLoad:true});f.send({type:'prefetch',pieces:['Hello there.'],voice:'af_heart',speed:1});await f.settle()
  f.send({type:'dispose'});await f.settle();f.load.resolve(f.model);await f.settle()
  assert.equal(f.events.includes('generate'),false)
  assert.equal(f.events.filter(e=>e==='dispose').length,1)
  assert.equal(f.messages.filter(m=>m.type==='disposed').length,1)
})
test('disposal waits for active inference, suppresses stale audio, and acknowledges only after release',async()=>{
  const f=await fixture({slowGenerate:true,slowDispose:true});f.send({type:'speak',id:1,pieces:['A sentence.'],voice:'af_heart',speed:1});await f.settle()
  assert.equal(f.events.includes('generate'),true);f.send({type:'dispose'});await f.settle()
  assert.equal(f.events.includes('dispose'),false);f.generation.resolve();await f.settle()
  assert.equal(f.events.includes('dispose'),true);assert.equal(f.messages.some(m=>m.type==='disposed'),false)
  assert.equal(f.messages.some(m=>m.type==='chunk'),false)
  f.disposal.resolve();await f.settle();assert.equal(f.messages.filter(m=>m.type==='disposed').length,1)
})
test('duplicate retirement and new work cannot resurrect the old engine',async()=>{
  const f=await fixture();f.send({type:'warm'});await f.settle();f.send({type:'dispose'});f.send({type:'dispose'});await f.settle()
  const count=f.events.length;f.send({type:'speak',id:2,pieces:['Never render.'],voice:'af_heart',speed:1});await f.settle()
  assert.equal(f.events.length,count);assert.equal(f.events.filter(e=>e==='dispose').length,1)
})
