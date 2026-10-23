'use strict';
(()=>{
  let sequence=0;
  const pending=new Map();
  function request(action,data={}) {
    return new Promise((resolve,reject)=>{
      const id=++sequence;
      const timer=setTimeout(()=>{pending.delete(id);reject(new Error('本机模块响应超时，请恢复定位后重试'));},30000);
      pending.set(id,{resolve,reject,timer});
      window.webkit.messageHandlers.routeLab.postMessage({id,action,data});
    });
  }
  window.routeLabReply=(id,result,error)=>{
    const item=pending.get(id);if(!item)return;
    clearTimeout(item.timer);pending.delete(id);
    error?item.reject(new Error(error)):item.resolve(result);
  };
  window.RouteLabNative={request};
  const original=window.fetch.bind(window);
  window.fetch=async(url,options={})=>{
    if(typeof url!=='string'||!url.startsWith('/api/'))return original(url,options);
    try {
      const result=await request(url.slice(5),options.body?JSON.parse(options.body):{});
      return new Response(JSON.stringify(result),{status:200,headers:{'Content-Type':'application/json'}});
    }catch(error){return new Response(JSON.stringify({error:error.message}),{status:400,headers:{'Content-Type':'application/json'}});}
  };
})();
