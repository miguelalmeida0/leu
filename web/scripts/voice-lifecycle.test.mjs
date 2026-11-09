import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import vm from 'node:vm'
import ts from 'typescript'

// Execute the real voice module. Only external browser/audio/worker boundaries
// are doubled: these tests prove lifecycle contracts, never audio quality or MB.
async function fixture({ systemVoices, touch = false, consent = true } = {}) {
  const contexts=[],workers=[],storage=new Map(),timers=new Map();let clock=0,timerId=0
  if (consent) storage.set('leu.voice.used', '1')
  class AudioContext {
    state='running';currentTime=0;destination={};nodes=[];suspensions=0;rejectSuspend=false
    constructor(){contexts.push(this)}
    close(){this.state='closed';return Promise.resolve()}
    resume(){return Promise.resolve().then(()=>{this.state='running'})}
    suspend(){this.suspensions++;return Promise.resolve().then(()=>{if(this.rejectSuspend)throw Error('context unavailable');this.state='suspended'})}
    createBuffer(channels,length,rate){return {duration:length/rate,channels,length,rate,copyToChannel(samples){this.samples=Array.from(samples)}}}
    createBufferSource(){const node={buffer:null,onended:null,connected:false,stopped:false,failStop:false,
      connect(){this.connected=true},disconnect(){this.connected=false},start(at){this.at=at},
      stop(){if(this.failStop)throw Error('already stopped');this.stopped=true},
      finish(){this.onended?.()}}
      this.nodes.push(node);return node
    }
  }
  class Worker {
    messages=[];onmessage=null;terminated=false
    constructor(){workers.push(this)}
    postMessage(message){this.messages.push(message)}
    terminate(){this.terminated=true}
    emit(data){this.onmessage?.({data})}
  }
  const store={voice:'af_heart'}
  const spoken=[]
  const speechSynthesis={getVoices:()=>systemVoices,cancel(){},pause(){},resume(){},speak:utterance=>spoken.push(utterance)}
  class SpeechSynthesisUtterance { constructor(text){this.text=text;this.voice=null} }
  const context=vm.createContext({console,URL,Float32Array,queueMicrotask,AudioContext,Worker,
    setTimeout:(fn,ms)=>{const id=++timerId;timers.set(id,{fn,at:clock+ms});return id},clearTimeout:id=>timers.delete(id),
    window:{matchMedia:()=>({matches:touch}),...(systemVoices?{speechSynthesis}:{})},
    speechSynthesis,SpeechSynthesisUtterance,navigator:{storage:{persist:async()=>true}},
    localStorage:{getItem:key=>storage.get(key)??null,setItem:(key,value)=>storage.set(key,value)}})
  const file=new URL('../src/lib/voice.ts',import.meta.url)
  const code=ts.transpileModule(await readFile(file,'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ESNext}}).outputText
  const module=new vm.SourceTextModule(code,{context,initializeImportMeta:meta=>{meta.url=file.href}})
  await module.link(specifier=>{
    const exports=specifier==='react'?{useSyncExternalStore:(_subscribe,snapshot)=>snapshot()}:
      specifier==='./store'?{getState:()=>store,update:fn=>Object.assign(store,fn(store)),useStore:fn=>fn(store)}:null
    if(!exports)throw Error('Unexpected dependency '+specifier)
    return new vm.SyntheticModule(Object.keys(exports),function(){for(const [key,value] of Object.entries(exports))this.setExport(key,value)},{context})
  })
  await module.evaluate()
  const voice=module.namespace
  const settle=async()=>{for(let i=0;i<5;i++)await Promise.resolve()}
  const request=()=>workers[0].messages.filter(m=>m.type==='speak').at(-1)
  function deliver(){workers[0].emit({type:'chunk',id:request().id,index:0,from:0,to:1,samples:new Float32Array(24000).fill(0.2),rate:24000,ms:1})}
  function done(){workers[0].emit({type:'done',id:request().id})}
  function play(then){voice.speak(['One complete sentence.'],'reader',0,then);deliver();return contexts[0].nodes.at(-1)}
  const advance=async ms=>{clock+=ms;for(const [id,t] of [...timers])if(t.at<=clock){timers.delete(id);t.fn()}await settle()}
  return {voice,contexts,workers,settle,request,deliver,done,play,advance,spoken}
}

const localVoice={voiceURI:'local-en',name:'Local English',lang:'en-US',localService:true,default:false}
const remoteVoice={voiceURI:'remote-en',name:'Remote English',lang:'en-US',localService:false,default:true}

test('system voice menu exposes only local English services',async()=>{
  const f=await fixture({systemVoices:[remoteVoice,localVoice,{...localVoice,voiceURI:'local-fr',lang:'fr-FR'}]})
  assert.deepEqual(Array.from(f.voice.systemVoices(),voice=>voice.id),['system:local-en'])
})
test('phone fallback uses an explicit local voice even when the browser default is remote',async()=>{
  const f=await fixture({systemVoices:[remoteVoice,localVoice],touch:true})
  f.voice.speak('Private document passage.')
  assert.equal(f.spoken.length,1);assert.equal(f.spoken[0].voice,localVoice)
})
test('a previously saved remote voice cannot send document text to that service',async()=>{
  const f=await fixture({systemVoices:[remoteVoice,localVoice]})
  f.voice.chooseVoice('system:remote-en');f.voice.speak('Private document passage.')
  assert.equal(f.spoken.length,1);assert.equal(f.spoken[0].voice,localVoice)
})
test('missing or remote-only system voices fail closed without browser-default speech',async()=>{
  for(const systemVoices of [[],[remoteVoice],[{...localVoice,localService:undefined}]]){
    const f=await fixture({systemVoices,touch:true});f.voice.speak('Private document passage.')
    assert.equal(f.spoken.length,0);assert.equal(f.voice.useVoice().status,'idle')
    assert.match(f.voice.useVoice().notice,/local English voice/i)
  }
})
test('Kokoro failure cannot fall back to a remote speech service',async()=>{
  const f=await fixture({systemVoices:[remoteVoice]});f.voice.speak('Private document passage.')
  f.workers[0].emit({type:'error',id:f.request().id,message:'Synthetic model failure'})
  assert.equal(f.spoken.length,0);assert.equal(f.voice.useVoice().status,'idle')
})
test('an explicitly selected local system voice remains available',async()=>{
  const alternate={...localVoice,voiceURI:'local-alternate',name:'Alternate'}
  const f=await fixture({systemVoices:[remoteVoice,localVoice,alternate]})
  f.voice.chooseVoice('system:local-alternate');f.voice.speak('Private document passage.')
  assert.equal(f.spoken.length,1);assert.equal(f.spoken[0].voice,alternate)
})

test('stop suspends idle audio and detaches stopped playback buffers',async()=>{
  const f=await fixture(),node=f.play();await f.settle();f.voice.stop();await f.settle()
  assert.equal(f.contexts[0].state,'suspended');assert.equal(node.connected,false);assert.equal(node.buffer,null)
  assert.equal(f.voice.useVoice().status,'idle')
})
test('natural completion releases its node and suspends audio',async()=>{
  const f=await fixture(),node=f.play();f.done();node.finish();await f.settle()
  assert.equal(f.contexts[0].state,'suspended');assert.equal(node.connected,false);assert.equal(node.buffer,null)
})
test('stop during model loading suspends audio and ignores late chunks',async()=>{
  const f=await fixture();f.voice.speak(['Loading passage.']);f.voice.stop();f.deliver();await f.settle()
  assert.equal(f.contexts[0].state,'suspended');assert.equal(f.contexts[0].nodes.length,0)
})
test('pause and resume preserve scheduled buffers, voice and the warm worker',async()=>{
  const f=await fixture(),node=f.play(),buffer=node.buffer;await f.settle()
  f.voice.pause();await f.settle();assert.equal(f.contexts[0].state,'suspended');assert.equal(node.buffer,buffer)
  assert.equal(node.connected,true);assert.equal(node.stopped,false);f.voice.resume();await f.settle()
  assert.equal(f.contexts[0].state,'running');assert.equal(f.voice.useVoice().status,'speaking')
  assert.equal(f.workers.length,1);assert.equal(f.request().voice,'af_heart')
})
test('same-task stop and replay do not suspend the replacement playback',async()=>{
  const f=await fixture(),old=f.play();await f.settle();f.voice.stop();const next=f.play();await f.settle()
  assert.equal(f.contexts[0].state,'running');assert.equal(f.contexts[0].suspensions,0)
  assert.equal(old.buffer,null);assert.notEqual(next.buffer,null);assert.equal(f.workers.length,1)
})
test('natural page continuation keeps new playback running',async()=>{
  const f=await fixture();let next
  const old=f.play(()=>{next=f.play()});f.done();old.finish();await f.settle()
  assert.equal(f.contexts[0].state,'running');assert.equal(f.contexts[0].suspensions,0)
  assert.equal(old.buffer,null);assert.notEqual(next.buffer,null);assert.equal(f.voice.useVoice().status,'speaking')
})
test('an already-stopped source cannot prevent disconnect and buffer release',async()=>{
  const f=await fixture(),node=f.play();node.failStop=true;f.voice.stop();await f.settle()
  assert.equal(node.connected,false);assert.equal(node.buffer,null);assert.equal(f.contexts[0].state,'suspended')
})
test('a rejected idle suspension does not reject stop or poison the next playback',async()=>{
  const f=await fixture();f.play();f.contexts[0].rejectSuspend=true;f.voice.stop();await f.settle()
  f.contexts[0].rejectSuspend=false;f.play();await f.settle();assert.equal(f.voice.useVoice().status,'speaking')
  assert.equal(f.contexts[0].state,'running')
})

test('two minutes of true idle retires the engine, then terminates only after acknowledgement',async()=>{
  const f=await fixture();f.play();f.voice.stop();await f.advance(119999)
  assert.equal(f.workers[0].messages.some(m=>m.type==='dispose'),false)
  await f.advance(1);assert.equal(f.workers[0].messages.at(-1).type,'dispose')
  assert.equal(f.workers[0].terminated,false);assert.equal(f.contexts[0].state,'closed')
  f.workers[0].emit({type:'disposed'});await f.settle()
  assert.equal(f.workers[0].terminated,true);assert.equal(f.voice.useVoice().kokoro,'unknown')
})
test('active and paused speech never unloads, and replay cancels the idle deadline',async()=>{
  const f=await fixture();f.play();await f.advance(120000);f.voice.pause();await f.advance(120000)
  assert.equal(f.workers[0].messages.some(m=>m.type==='dispose'),false)
  f.voice.stop();await f.advance(119999);f.play();await f.advance(1)
  assert.equal(f.workers[0].messages.some(m=>m.type==='dispose'),false)
})
test('Play during disposal waits for acknowledgement and preserves voice and new AudioContext',async()=>{
  const f=await fixture();f.play();f.voice.stop();await f.advance(120000)
  f.voice.speak(['New passage.']);await f.settle();assert.equal(f.workers.length,1)
  f.workers[0].emit({type:'disposed'});await f.settle()
  assert.equal(f.workers.length,2);assert.equal(f.workers[1].messages.at(-1).voice,'af_heart')
  assert.equal(f.contexts.at(-1).state,'running')
  f.workers[0].emit({type:'ready'});assert.notEqual(f.voice.useVoice().kokoro,'ready')
})
test('stopping queued Play during disposal cannot restart speech',async()=>{
  const f=await fixture();f.play();f.voice.stop();await f.advance(120000)
  f.voice.speak(['Never play.']);f.voice.stop();f.workers[0].emit({type:'disposed'});await f.settle()
  assert.equal(f.workers.length,1);assert.equal(f.voice.useVoice().status,'idle')
})
test('prewarming without playback has an idle retirement deadline',async()=>{
  const f=await fixture();f.voice.warmVoice(true);f.workers[0].emit({type:'ready'});await f.advance(120000)
  assert.equal(f.workers[0].messages.at(-1).type,'dispose')
})
test('an empty passage does not cancel retirement of a resident model',async()=>{
  const f=await fixture();f.play();f.voice.stop();f.voice.speak('');await f.advance(120000)
  assert.equal(f.workers[0].messages.at(-1).type,'dispose')
})
test('failed disposal keeps ownership and ends queued Play with visible recovery',async()=>{
  const f=await fixture();f.play();f.voice.stop();await f.advance(120000)
  f.voice.speak(['Waiting.']);f.workers[0].emit({type:'dispose-error',message:'Release failed'});await f.settle()
  assert.equal(f.workers.length,1);assert.equal(f.workers[0].terminated,false)
  assert.equal(f.voice.useVoice().status,'idle');assert.match(f.voice.useVoice().notice,/Reload/)
})


test('first use waits for download consent without creating a worker', async () => {
  const f = await fixture({ consent: false })
  f.voice.speak('Private passage.')
  assert.equal(f.voice.useVoice().awaitingDownload, true)
  assert.equal(f.workers.length, 0)
  f.voice.cancelVoiceDownload()
  assert.equal(f.voice.useVoice().awaitingDownload, false)
  assert.equal(f.workers.length, 0)
  f.voice.speak('Another private passage.')
  f.voice.confirmVoiceDownload()
  assert.equal(f.workers.length, 1)
  assert.equal(f.voice.useVoice().status, 'loading')
})

test('cancel loading terminates the download worker and ignores late messages', async () => {
  const f = await fixture()
  f.voice.speak('Private passage.')
  const worker = f.workers[0]
  f.voice.cancelVoiceDownload()
  assert.equal(worker.terminated, true)
  assert.equal(worker.onmessage, null)
  assert.equal(f.voice.useVoice().status, 'idle')
  assert.equal(f.voice.useVoice().download, null)
  f.voice.speak('Retry passage.')
  assert.equal(f.workers.length, 2)
})
