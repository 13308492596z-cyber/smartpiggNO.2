const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
let outbound=[];
let ordinaryRequests=[];
const window={
 fetch:async(...args)=>{ordinaryRequests.push(args);return 'ordinary-network';},
 webkit:{messageHandlers:{routeLab:{postMessage:message=>outbound.push(message)}}}
};
vm.runInNewContext(fs.readFileSync(path.join(__dirname,'../Resources/web/native-bridge.js'),'utf8'),{window,Map,Promise,JSON,Response,Error,setTimeout,clearTimeout});
(async()=>{
 const configRequest=window.fetch('/api/config');
 const config=outbound.shift();assert.equal(config.action,'config');
 window.routeLabReply(config.id,{name:'test'},null);
 assert.deepEqual(await (await configRequest).json(),{name:'test'});
 const payload={points:[[0,0],[0,.001]],meters:10,minutes:1};
 const one=window.fetch('/api/preview',{body:JSON.stringify(payload)});
 const two=window.fetch('/api/state');
 const first=outbound.shift(),second=outbound.shift();
 assert.deepEqual(JSON.parse(JSON.stringify(first.data)),payload);
 window.routeLabReply(second.id,{phase:'idle'},null);
 window.routeLabReply(first.id,null,'invalid route');
 assert.equal((await two).status,200);
 const rejected=await one;assert.equal(rejected.status,400);assert.equal((await rejected.json()).error,'invalid route');
 window.routeLabReply(9999,{},null);
 assert.equal(await window.fetch('https://example.invalid/tile'),'ordinary-network');
 assert.equal(ordinaryRequests.length,1);
 console.log('Native bridge boundary checks passed');
})().catch(error=>{console.error(error);process.exitCode=1;});
