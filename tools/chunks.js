// Splits a JS file into top-level statements by asking V8 whether each growing chunk parses.
const vm=require('vm');
const ok=s=>{try{new vm.Script(s);return true}catch(e){return false}};
module.exports=function chunks(src){
  const L=src.split('\n'),out=[];let i=0;
  while(i<L.length){
    if(!L[i].trim()){i++;continue}
    let j=i,buf=L[i];
    while(!ok(buf)){j++;if(j>=L.length)throw new Error('unterminated statement at line '+(i+1));buf+='\n'+L[j]}
    // absorb continuations (else / .then / catch ...) that only parse when joined
    while(j+1<L.length&&/^\s*(else\b|catch\b|finally\b|\.|\)|,)/.test(L[j+1])){j++;buf+='\n'+L[j]}
    out.push({from:i+1,to:j+1,text:buf});i=j+1;
  }
  return out;
};
