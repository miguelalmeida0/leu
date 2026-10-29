(function () {
  'use strict';
  const direction = document.documentElement.dataset.direction;
  const intensity = direction === 'light' ? 1.3 : direction === 'craft' ? 1.25 : 1;
  const reduced = matchMedia('(prefers-reduced-motion: reduce)');
  let playing = !reduced.matches;
  let manuallyChosen = false;
  let active = 'nook';
  let frameCount = 0;
  let seconds = 0;
  let startedAt = performance.now();
  const status = document.getElementById('status');
  const meter = document.getElementById('elapsed');
  const toggle = document.getElementById('motion-toggle');
  const error = document.getElementById('asset-error');
  const shell = document.querySelector('.stage');
  const scenes = [...document.querySelectorAll('[data-scene]')];
  const controls = [...document.querySelectorAll('[data-select]')];
  const sample = { clear:null, globe:null, basket:null, room:null };
  const sceneSize = { nook:[900,826], basket:[1559,1147], globe:[1155,1066] };

  // Same-origin, untouched Leu Blender renders. On a downloaded HTML file,
  // use the public live website. No SVG recreation and no remote script library.
  const root = location.protocol === 'file:' ? 'https://leu.miguelalmeida.xyz' : '';
  document.querySelectorAll('img[data-art]').forEach(function(img) {
    img.addEventListener('error', () => { error.dataset.show='true'; error.textContent = 'This viewer cannot load the original artwork. Open the HTTPS preview in Safari.'; });
    img.src = root + '/art/' + img.dataset.art;
  });
  const canvases = [...document.querySelectorAll('canvas[data-fx]')].map(canvas => ({
    canvas, ctx:canvas.getContext('2d'), kind:canvas.dataset.fx,
    virtual: canvas.dataset.fx === 'rain' ? [464,384] : sceneSize[canvas.dataset.fx === 'air' ? 'nook' : canvas.dataset.fx],
  }));
  const map = new Map(canvases.map(c=>[c.kind,c]));
  let sizeObserver = null;
  function resizeCanvas(c) {
    const rect = c.canvas.getBoundingClientRect();
    if (rect.width < 1 || rect.height < 1) return;
    const dpr = Math.min(2, devicePixelRatio || 1);
    const width = Math.max(1,Math.floor(rect.width*dpr));
    const height = Math.max(1,Math.floor(rect.height*dpr));
    if(c.canvas.width !== width || c.canvas.height !== height) {
      c.canvas.width=width; c.canvas.height=height;
    }
    c.ctx.setTransform(width/c.virtual[0],0,0,height/c.virtual[1],0,0);
  }
  function resizeAll() { canvases.forEach(resizeCanvas); }
  if (typeof ResizeObserver !== 'undefined') {
    sizeObserver = new ResizeObserver(resizeAll);
    canvases.forEach(x=>sizeObserver.observe(x.canvas));
  }
  addEventListener('resize',resizeAll,{passive:true});
  resizeAll();

  function setPlaying(value, chosen=false) {
    playing=value;
    if (chosen) manuallyChosen=true;
    document.documentElement.dataset.playing=String(playing);
    toggle.textContent = playing ? 'Pause motion' : 'Play motion';
    toggle.setAttribute('aria-pressed',String(playing));
    status.textContent = playing ? 'Motion is running' : reduced.matches && !manuallyChosen ? 'Reduce Motion is on — tap Play' : 'Motion paused';
    if (playing) startedAt=performance.now()-seconds*1000;
  }
  setPlaying(playing);
  toggle.addEventListener('click',()=>setPlaying(!playing,true));
  reduced.addEventListener('change',()=>{if(!manuallyChosen) setPlaying(!reduced.matches)});
  function chooseScene(scene) {
    active=scene;
    scenes.forEach(el=>{const on=el.dataset.scene===scene;el.classList.toggle('current',on);el.setAttribute('aria-hidden',String(!on))});
    controls.forEach(button=>{const on=button.dataset.select===scene;button.setAttribute('aria-selected',String(on));button.tabIndex=on?0:-1});
    document.getElementById('current-scene').textContent=scene==='nook'?'Rain through the window':scene==='basket'?'The moving yarn':'Snow inside the glass';
    resizeAll();
  }
  controls.forEach(button=>button.addEventListener('click',()=>chooseScene(button.dataset.select)));
  chooseScene(active);

  function seeded(i,seed=1) { let x=Math.sin((i+seed)*127.1)*43758.5453123; return x-Math.floor(x); }
  const rain=Array.from({length:direction==='weather'?130:direction==='light'?65:45},(_,i)=>({
    x:seeded(i,1)*464, y:seeded(i,2)*384,
    speed:30+seeded(i,3)*(direction==='weather'?80:55),
    length:6+seeded(i,4)*20, alpha:.18+seeded(i,5)*.38,
  }));
  const motes=Array.from({length:27},(_,i)=>({x:seeded(i,7)*900,y:seeded(i,8)*826,phase:seeded(i,9)*7,r:1+seeded(i,10)*2.3}));
  const flakes=Array.from({length:direction==='craft'?220:direction==='light'?145:165},(_,i)=>({
    x:seeded(i,11)*1.9-0.95, y:seeded(i,12)*1.8-0.9,
    speed:10+seeded(i,13)*27, radius:1+seeded(i,14)*2.3, phase:seeded(i,15)*6.28,
    alpha:.37+seeded(i,16)*.5,
  }));

  function clear(ctx, w, h) {ctx.clearRect(0,0,w,h)}
  function glow(ctx,x,y,r,alpha,color) {
    const g=ctx.createRadialGradient(x,y,0,x,y,r);
    g.addColorStop(0,`rgba(${color},${alpha})`);
    g.addColorStop(.37,`rgba(${color},${alpha*.27})`);
    g.addColorStop(1,`rgba(${color},0)`);
    ctx.fillStyle=g;ctx.fillRect(x-r,y-r,2*r,2*r);
  }
  function drawRain(t) {
    const c=map.get('rain'); if(!c) return;const {ctx}=c;
    clear(ctx,464,384);
    const wind=Math.sin(t*.34)*3;
    for (const p of rain) {
      const x=p.x+wind, y=((p.y+t*p.speed)%445)-35;
      const alpha=p.alpha * intensity;
      ctx.strokeStyle=`rgba(232,243,237,${alpha})`;
      ctx.lineWidth=.8+p.length/16;ctx.lineCap='round';
      ctx.beginPath();ctx.moveTo(x,y);ctx.lineTo(x-1.3,y+p.length);ctx.stroke();
      if(p.length>17)glow(ctx,x,y+p.length,3.2,alpha*.4,'241,248,243');
    }
    if (direction==='light') {
      const x=135+Math.sin(t*.65)*140;
      glow(ctx,x,170,175,.15,'255,218,149');
    }
    if (direction==='craft') {
      for(let i=0;i<22;i++) {
        const x=35+seeded(i,91)*380, y=((seeded(i,92)*420+t*(8+seeded(i,93)*15))%420)-17;
        glow(ctx,x,y,4,.08,'255,234,188');
      }
    }
  }
  function drawAir(t) {
    const c=map.get('air');if(!c)return;const {ctx}=c;
    clear(ctx,900,826);
    // Original cup position as measured from the current NookScene source.
    for(let i=0;i<(direction==='weather'?5:4);i++) {
      const phase=(t/5.8+i/5)%1;
      const rise=phase*130;const fade=Math.sin(Math.PI*phase);
      const x=679+Math.sin(t*.6+i*1.6)*9+phase*11;
      const y=656-rise;
      ctx.beginPath();ctx.moveTo(x-7,y+22);
      ctx.bezierCurveTo(x-24+Math.sin(t*.35+i)*7,y+7,x+25,y-20,x-10,y-44);
      ctx.strokeStyle=`rgba(250,246,228,${fade*.31*intensity})`;
      ctx.lineWidth=4.8+phase*2.7;ctx.lineCap='round';ctx.stroke();
      glow(ctx,x,y,17+phase*8,fade*.11,'255,246,223');
    }
    if (direction!=='weather') {
      const p=(Math.sin(t*.42)*.5+.5);
      glow(ctx,240+p*350,260,230,(direction==='light'?.15:.07)*intensity,'255,223,154');
    }
    if (direction==='craft') {
      ctx.save();ctx.beginPath();ctx.moveTo(350,572);ctx.bezierCurveTo(430,558,540,570,656,556);
      ctx.setLineDash([4,11]);ctx.lineDashOffset=-t*22;ctx.lineWidth=2.8;ctx.strokeStyle='rgba(246,206,167,.48)';ctx.stroke();ctx.restore();
    }
    for(let i=0;i<motes.length;i++){
      const p=motes[i];const x=p.x+Math.sin(t*.31+p.phase)*9;
      const y=p.y+Math.sin(t*.22+p.phase)*5;
      if(y<380)continue;
      glow(ctx,x,y,p.r*3,.045,'255,233,182');
    }
  }
  function drawBasket(t) {
    const c=map.get('basket');if(!c)return;const {ctx}=c;
    clear(ctx,1559,1147);
    const amp=direction==='craft'?48:direction==='light'?24:34;
    const swing=Math.sin(t*1.1)*amp+Math.sin(t*.37+.4)*amp*.28;
    // The original needle tip and loose ball locations, not a replacement drawing.
    const a={x:863,y:41},b={x:1032,y:716};
    const cp1={x:901+swing*.65,y:238},cp2={x:873-swing,y:579};
    ctx.beginPath();ctx.moveTo(a.x,a.y);ctx.bezierCurveTo(cp1.x,cp1.y,cp2.x,cp2.y,b.x,b.y);
    ctx.lineWidth=7;ctx.strokeStyle='rgba(100,58,49,.36)';ctx.lineCap='round';ctx.stroke();
    ctx.beginPath();ctx.moveTo(a.x,a.y);ctx.bezierCurveTo(cp1.x,cp1.y,cp2.x,cp2.y,b.x,b.y);
    ctx.lineWidth=3.9;ctx.strokeStyle='#F0C3B3';ctx.stroke();
    if(direction==='craft') {
      const m=(t*.3)%1; const y=41+675*m;
      glow(ctx,895+swing*.4+Math.sin(m*6)*30,y,28,.28,'255,222,194');
      for(let i=0;i<22;i++) {
        const x=820+seeded(i,68)*340,y=150+seeded(i,69)*390;
        glow(ctx,x+Math.sin(t*.23+i)*9,y,10,.05,'255,243,225');
      }
    }
    if(direction==='light'){
      const x=650+Math.sin(t*.49)*250;
      glow(ctx,x,392,320,.17,'255,219,148');
      glow(ctx,1040,705,90,.14+.1*Math.sin(t*.68),'255,203,167');
    }
  }
  function drawGlobe(t) {
    const c=map.get('globe');if(!c)return;const {ctx}=c;
    clear(ctx,1155,1066);
    const cx=512,cy=315.07,R=297;
    ctx.save();ctx.beginPath();ctx.arc(cx,cy,R,0,Math.PI*2);ctx.clip();
    for(const p of flakes) {
      const radial=Math.sqrt(p.x*p.x+p.y*p.y);
      const x=cx+p.x*R*.91+Math.sin(t*.46+p.phase)*(direction==='craft'?29:10);
      const y=cy+(((p.y+1)*R + t*p.speed)%(R*2)) -R;
      if ((x-cx)*(x-cx)+(y-cy)*(y-cy)>(R-9)*(R-9))continue;
      const r=p.radius*(direction==='craft'?1.4:1.05);
      ctx.beginPath();ctx.arc(x,y,r,0,Math.PI*2);
      ctx.fillStyle=`rgba(255,248,228,${p.alpha})`;ctx.fill();
      if(r>2.4)glow(ctx,x,y,r*5,.13,'255,249,237');
    }
    if(direction==='light'){
      const f=.5+.5*Math.sin(t*.65);
      glow(ctx,454,363,76,.17+f*.17,'255,202,102');
      glow(ctx,508,363,76,.13+(1-f)*.18,'255,204,111');
      glow(ctx,560,367,74,.11+f*.16,'255,205,120');
    }
    if(direction==='craft'){
      const x=512+Math.sin(t*.47)*85;
      glow(ctx,x,252,146,.12,'255,242,213');
    }
    ctx.restore();
  }
  let lastFrame=0;
  const fps=matchMedia('(pointer: coarse)').matches?24:30;
  function frame(now) {
    requestAnimationFrame(frame);
    if(!playing||document.hidden)return;
    if(now-lastFrame<1000/fps-1)return;
    lastFrame=now;
    if (active==='nook'){drawRain(now/1000);drawAir(now/1000)}
    else if(active==='basket')drawBasket(now/1000);
    else if(active==='globe')drawGlobe(now/1000);
    frameCount++;
    seconds=(now-startedAt)/1000;
    meter.textContent=Math.floor(seconds)+'s';
  }
  requestAnimationFrame(frame);
  window.__LEU_MOTION_TEST = {
    get frames(){return frameCount}, get playing(){return playing}, get active(){return active},
    get artwork(){return [...document.querySelectorAll('img[data-art]')].map(i=>({name:i.dataset.art,ready:i.complete&&i.naturalWidth>0}))},
  };
})();
