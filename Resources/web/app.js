'use strict';
const $ = id => document.getElementById(id);
let map, line, markers=[], mover, points=[], state={}, token='', busy=false, noticeUntil=0;
const labels={idle:'未开始',positioned:'已定位到起点',countdown:'准备开始',running:'正在模拟',paused:'已暂停',finished:'坐标发送完毕',error:'需要处理',recovery:'需要恢复定位',restoring:'正在恢复'};
function message(text,error=false){$('message').textContent=text;document.querySelector('footer').classList.toggle('error',error);noticeUntil=Date.now()+8000;}
function locked(){return !!state.needs_restore||['running','paused','restoring'].includes(state.phase);}
function payload(){return {points,meters:Number($('meters').value),minutes:Number($('minutes').value)};}
function save(){localStorage.setItem('routelab-ios-plan-v1',JSON.stringify(payload()));showPace();}
function showPace(){const {meters,minutes}=payload();if(!(meters>0&&minutes>0)){$('pace').textContent='请输入距离与时长';return;}const pace=minutes*1000/meters;const seconds=Math.round(pace*60);$('pace').textContent='计划配速：'+Math.floor(seconds/60)+'分'+String(seconds%60).padStart(2,'0')+'秒/公里 · '+(meters>=1000&&meters<=5000&&pace>=3&&pace<=10?'处于学校规则范围内':'超出学校里程或配速范围');}
async function api(action,data={}){
  const res=await fetch('/api/'+action,{method:'POST',headers:{'Content-Type':'application/json','X-RouteLab-Token':token},body:JSON.stringify(data)});
  if(!res.ok){let error=await res.json();throw new Error(error.error||'请求失败');}
  return action==='gpx'?res.blob():res.json();
}
function controls(){
  const disabled=busy||locked();
  for(const id of ['undo','close','clear','import','coordinates','meters','minutes'])$(id).disabled=disabled;
  const deviceReady=state.device?.connected||state.device?.dry_run;
  $('start').disabled=busy||state.phase!=='positioned'||points.length<2||!deviceReady;
  $('anchor').disabled=busy||locked()||points.length<2||!deviceReady;
  $('preview').disabled=busy||points.length<2;
  $('export').disabled=busy||points.length<2;
  $('pause').disabled=busy||!['running','countdown'].includes(state.phase);
  $('pause').textContent=state.phase==='countdown'?'取消倒计时':'暂停';
  $('resume').disabled=busy||state.phase!=='paused';
  $('restore').disabled=busy||state.phase==='restoring';
  $('device').disabled=busy||['running','countdown'].includes(state.phase);
}
function lengthOfRoute(){return points.slice(1).reduce((sum,p,i)=>sum+map.distance(points[i],p),0);}
function redraw(fit=false){
  markers.forEach(m=>m.remove());markers=[];
  line.setLatLngs(points);
  points.forEach((p,i)=>{if(i===points.length-1&&i>0&&map.distance(points[0],p)<.001)return;markers.push(L.marker(p,{icon:L.divIcon({className:'route-dot',html:String(i+1),iconSize:[20,20],iconAnchor:[10,10]})}).addTo(map));});
  $('route-length').textContent=points.length>1?lengthOfRoute().toFixed(1)+' 米':'—';
  $('coordinates').value=points.map(p=>p.map(n=>Number(n).toFixed(8)).join(',')).join('\n');
  if(fit&&points.length>1)map.fitBounds(line.getBounds(),{padding:[60,60],maxZoom:19});
  save();controls();
}
function showState(next){
  state=next;
  if(next.token)token=next.token;
  $('device-name').textContent=next.device?.name+(next.device?.connected?' · 本机':'');
  $('device').classList.toggle('connected',!!next.device?.connected);
  $('phase').textContent=next.phase==='countdown'?'准备开始 · '+next.countdown_remaining+' 秒':labels[next.phase]||'未开始';
  const activePlan=next.needs_restore&&next.plan;
  const meters=activePlan?.meters||Number($('meters').value)||1000;
  const percent=activePlan?Math.min(100,next.elapsed/activePlan.seconds*100):0;
  $('distance').textContent=(activePlan?next.traveled||0:0).toFixed(1)+' / '+meters;
  $('progress').value=percent;$('percent').textContent=Math.floor(percent)+'%';
  if(next.point){if(!mover)mover=L.marker(next.point,{icon:L.divIcon({className:'moving-dot',iconSize:[22,22],iconAnchor:[11,11]})}).addTo(map);else mover.setLatLng(next.point);}
  else if(mover){mover.remove();mover=null;}
  if(Date.now()>noticeUntil){$('message').textContent=next.message;document.querySelector('footer').classList.toggle('error',['error','recovery'].includes(next.phase));}
  controls();
}
async function operation(action){
  if(busy)return;busy=true;controls();
  try{
    const result=await api(action,payload());
    showState(result);message(result.message||'操作完成');
  }catch(e){message(e.message,true);}finally{busy=false;await poll();controls();}
}
async function poll(){try{const r=await fetch('/api/state');if(!r.ok)throw new Error();showState(await r.json());}catch{message('本机模块未响应；请重新打开应用并恢复定位。',true);$('start').disabled=true;}}
async function preview(){
  try{const plan=await api('preview',payload());redraw(true);message('路线 '+plan.route_length.toFixed(1)+' 米 · 计划发送 '+plan.meters+' 米 / '+(plan.seconds/60).toFixed(1)+' 分钟');}
  catch(e){message(e.message,true);}
}
async function init(){
  const config=await (await fetch('/api/config')).json();
  let saved={};try{saved=JSON.parse(localStorage.getItem('routelab-ios-plan-v1'))||{};}catch{}
  points=Array.isArray(saved.points)?saved.points:config.route||[];
  if(points.some(p=>!Array.isArray(p)||p.length!==2||!p.every(Number.isFinite)||Math.abs(p[0])>90||Math.abs(p[1])>180))points=[];
  $('meters').value=saved.meters||1000;$('minutes').value=saved.minutes||10;
  $('center-lat').value=config.center[0];$('center-lon').value=config.center[1];
  $('campus-name').textContent=config.name;
  map=L.map('map',{zoomControl:false,doubleClickZoom:false}).setView(config.center,config.zoom);
  L.control.zoom({position:'bottomright'}).addTo(map);
  let activeTiles,loaded=0;
  function setTiles(key){
    if(activeTiles)activeTiles.remove();loaded=0;$('map-notice').hidden=true;
    const selected=config.tiles.find(t=>t.key===key)||config.tiles[0];
    activeTiles=L.tileLayer(selected.url,{maxZoom:selected.maxZoom||19,attribution:selected.attribution,keepBuffer:1}).addTo(map);
    activeTiles.on('tileload',()=>{loaded++;$('map-notice').hidden=true;});
    activeTiles.on('tileerror',()=>{if(!loaded){$('map-notice').textContent='底图暂未加载，可切换右上角底图；不要依据空白底图定位路线。';$('map-notice').hidden=false;}});
    const layer=activeTiles;setTimeout(()=>{if(activeTiles===layer&&!loaded){$('map-notice').textContent='底图响应较慢，可切换右上角底图或检查网络。';$('map-notice').hidden=false;}},10000);
  }
  $('tiles').innerHTML='';config.tiles.forEach(t=>{const option=document.createElement('option');option.value=t.key;option.textContent=t.name;$('tiles').append(option);});
  const tileKey=localStorage.getItem('routelab-ios-tiles')||config.default_tile||config.tiles[0].key;
  $('tiles').value=tileKey;
  $('tiles').onchange=()=>{localStorage.setItem('routelab-ios-tiles',$('tiles').value);setTiles($('tiles').value);};setTiles(tileKey);
  line=L.polyline([],{color:'#23624a',weight:4}).addTo(map);
  map.on('click',e=>{if(locked()){message('请先恢复真实定位，再编辑一条新路线');return;}if(points.length>=1000){message('最多支持 1000 个路线点',true);return;}points.push([e.latlng.lat,e.latlng.lng]);redraw();});
  $('undo').onclick=()=>{points.pop();redraw();};
  $('close').onclick=()=>{if(points.length>2&&map.distance(points[0],points[points.length-1])>0.001){points.push([...points[0]]);redraw();}else message('请先选择至少三个点，再闭合路线');};
  $('clear').onclick=()=>{points=[];redraw();};
  $('go').onclick=()=>{const p=[Number($('center-lat').value),Number($('center-lon').value)];if(!$('center-lat').value.trim()||!$('center-lon').value.trim()||!p.every(Number.isFinite)||Math.abs(p[0])>90||Math.abs(p[1])>180){message('请输入有效的纬度和经度',true);return;}map.setView(p,18);};
  $('import').onclick=()=>{
    try{const raw=$('coordinates').value.trim().split(/\r?\n/);const parsed=raw.map((v,i)=>{const pair=v.replace(/，/g,',').split(',');if(pair.length!==2||pair.some(s=>!s.trim()))throw new Error('第 '+(i+1)+' 行坐标格式有误');const p=pair.map(Number);if(!p.every(Number.isFinite)||Math.abs(p[0])>90||Math.abs(p[1])>180)throw new Error('第 '+(i+1)+' 行坐标无效');return p;});if(parsed.length<2||parsed.length>1000)throw new Error('请填写 2 至 1000 个路线点');points=parsed;redraw(true);message('坐标已导入；预览不会改变手机定位');}catch(e){message(e.message,true);}
  };
  $('preview').onclick=preview;
  $('export').onclick=async()=>{try{await window.RouteLabNative.request('share',payload());}catch(e){message(e.message,true);}};
  ['anchor','pause','resume','restore'].forEach(action=>$(action).onclick=()=>operation(action));
  $('start').onclick=()=>operation('countdown');
  $('device').onclick=()=>operation('refresh');
  ['meters','minutes'].forEach(id=>$(id).onchange=()=>{save();controls();});
  redraw(points.length>1);await poll();
  if(state.needs_restore&&state.plan){points=state.plan.points;$('meters').value=state.plan.meters;$('minutes').value=state.plan.seconds/60;redraw(true);}
  setInterval(poll,1500);
}
init().catch(e=>message('页面初始化失败：'+e.message,true));
