const { chromium } = require('playwright');
(async()=>{const b=await chromium.launch({args:['--use-gl=swiftshader','--enable-webgl','--ignore-gpu-blocklist']});
for(const [m,w,h,o] of [['icon',512,512,'icon_512_3d.png'],['t1',1920,1080,'thumb_dogfight_3d.png'],['t2',1920,1080,'thumb_islands_3d.png']]){
 if(process.argv[2]&&process.argv[2]!==m)continue;
 const p=await b.newPage({viewport:{width:w,height:h},deviceScaleFactor:2});p.on('pageerror',e=>console.log('ERR',m,e.message));p.on('console',c=>{if(c.type()==='error')console.log('CON',c.text().slice(0,200))});
 await p.goto('http://localhost:8790/scene.html?m='+m);await p.waitForSelector('body[data-ready]',{timeout:180000});await p.waitForTimeout(300);
 await p.screenshot({path:o});console.log('ok',o);await p.close();}
await b.close();})();
