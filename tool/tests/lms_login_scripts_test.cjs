const assert = require('node:assert/strict');
const AsyncFunction = Object.getPrototypeOf(async function(){}).constructor;
const origin = 'https://ecampus.smu.ac.kr';
const location = {origin, protocol:'https:', port:'', hostname:'ecampus.smu.ac.kr', pathname:'/', search:'', href:origin+'/'};
const anchor = href => ({getAttribute: name => name === 'href' ? href : null});
const document = (links=[], password=false, bodyId='page-site-index') => ({
  body: {id:bodyId}, documentElement: {outerHTML:'fixture-dashboard'},
  querySelector: selector => selector === 'input[type="password"]' && password ? {} : null,
  querySelectorAll: selector => selector === 'a[href]' ? links.map(anchor) : [],
});
const authenticate = new AsyncFunction('document','location','origin','fetch','DOMParser',scripts.authenticationScript);
let checks=0;
async function verify(doc, preferences, result={}) {
  const requests=[];
  const fetch = async (url, options) => {
    requests.push({url,options});
    assert.equal(url, origin+'/user/preferences.php');
    assert.equal(options.method,'GET');
    assert.equal(options.redirect,'manual');
    assert.equal(options.credentials,'same-origin');
    return {ok:true,status:200,type:'basic',url,headers:{get:()=> 'text/html'},text:async()=> 'preferences-fixture',...result};
  };
  class DOMParser { parseFromString() { return preferences; } }
  const value=await authenticate(doc, location, origin, fetch, DOMParser);
  return {value,requests};
}
(async()=>{
  let r=await verify(document(['/user/edit.php?id=123']));
  assert.equal(r.value.principal,'123'); assert.equal(r.requests.length,0); checks++;
  r=await verify(document(),document(['/user/edit.php?id=123'],false,'page-user-preferences'));
  assert.equal(r.value.principal,'123'); assert.equal(r.requests.length,1); checks++;
  r=await verify(document(['/user/profile.php?id=999']),document(['/user/edit.php?id=123'],false,'page-user-preferences'));
  assert.equal(r.value.principal,'123'); checks++;
  r=await verify(document([],true)); assert.equal(r.value.authenticationRequired,true); assert.equal(r.requests.length,0); checks++;
  r=await verify(document(['/user/edit.php?id=123','/user/edit.php?id=456'])); assert.equal(r.value.unrecognized,true); assert.equal(r.requests.length,0); checks++;
  r=await verify(document(),document(['/user/edit.php?id=123'],false,'page-login-index')); assert.equal(r.value.unrecognized,true); checks++;
  r=await verify(document(),document(['/user/edit.php?id=123','/user/edit.php?id=456'],false,'page-user-preferences')); assert.equal(r.value.unrecognized,true); checks++;
  r=await verify(document(),null,{ok:false,type:'opaqueredirect',status:0}); assert.equal(r.value.unrecognized,true); checks++;
  r=await verify(document(),null,{url:'https://other.test/user/preferences.php'}); assert.equal(r.value.unexpectedOrigin,true); checks++;
  r=await verify(document(),null,{url:origin+'/user/preferences.php?userid=456'}); assert.equal(r.value.unexpectedOrigin,true); checks++;
  r=await verify(document(),null,{status:401,ok:false}); assert.equal(r.value.authenticationRequired,true); checks++;
  const automatic = new AsyncFunction('document','location','window','stage','username','password','setTimeout',scripts.automaticLoginScript);
  const field=type=>({type,value:'',dispatchEvent(){}});
  const user=field('text'),pwd=field('password'); let submissions=0;
  const form={method:'post',action:origin+'/login/index.php',dataset:{},requestSubmit(){submissions++},querySelector:s=>s.includes('username')?user:s.includes('password')?pwd:null,querySelectorAll:()=>[]};
  const mobile={readyState:'complete',querySelectorAll:()=>[],querySelector:s=>s==='input[type="password"]'?pwd:s==='form.form-login'?form:null};
  const schedule=fn=>fn();
  r=await automatic(mobile,location,{},'entry','fixture-id','fixture-password',schedule); assert.equal(r.state,'credentialsSubmitted'); assert.equal(submissions,1); assert.equal(user.value,'fixture-id'); checks++;
  r=await automatic(mobile,location,{},'entry','fixture-id','fixture-password',schedule); assert.equal(r.state,'blocked'); assert.equal(submissions,1); checks++;
  delete form.dataset.dailyAutoSubmitted; form.action='https://other.test/login/index.php';
  r=await automatic(mobile,location,{},'entry','fixture-id','fixture-password',schedule); assert.equal(r.state,'blocked'); assert.equal(submissions,1); checks++;
  r=await automatic(mobile,{...location,protocol:'http:'},{},'entry','','',schedule); assert.equal(r.state,'blocked'); checks++;
  r=await automatic({readyState:'complete',querySelectorAll:()=>[],querySelector:()=>null},location,{},'submitted','','',schedule); assert.equal(r.state,'authenticated'); checks++;
  for (const [text,reason] of [
    ['아이디 또는 비밀번호가 올바르지 않습니다.', 'credentialsRejected'],
    ['계정 잠금 상태입니다.', 'accountLocked'],
    ['비밀번호 만료: 변경이 필요합니다.', 'passwordExpired'],
    ['추가 인증이 필요합니다.', 'additionalAuthentication'],
  ]) {
    const errors={...mobile,querySelectorAll:()=>[{getClientRects:()=>[{}],textContent:text+' private-user-do-not-return'}]};
    r=await automatic(errors,location,{},'submitted','fixture-id','fixture-password',schedule);
    assert.equal(r.state,'blocked'); assert.equal(r.failure,reason);
    assert.equal(JSON.stringify(r).includes('private-user-do-not-return'),false); checks++;
  }
  r=await automatic(mobile,{...location,hostname:'other.test'},{},'entry','fixture-id','fixture-password',schedule);
  assert.equal(r.state,'blocked'); assert.equal(submissions,1); checks++;
  delete form.dataset.dailyAutoSubmitted; form.action=origin+'/login/index.php';
  r=await automatic(mobile,location,{},'inspect','','',schedule);
  assert.equal(r.state,'waiting'); assert.equal(submissions,1); checks++;
  assert.equal(checks,22);
  console.log('LMS JS: 22 checks passed');
})().catch(e=>{console.error(e);process.exitCode=1;});
