/** Transport-independent Aura API client. No wallet keys or radio assumptions. */
export class AuraClient {
  constructor({baseURL, token=null, fetch: transport=globalThis.fetch}) {this.baseURL=baseURL.replace(/\/$/,'');this.token=token;this.fetch=(...args)=>transport(...args);}
  async request(path, body, method=body===undefined?'GET':'POST') {
    const response=await this.fetch(this.baseURL+path,{method,headers:{'Content-Type':'application/json',...(this.token?{Authorization:`Bearer ${this.token}`}:{})},...(body===undefined?{}:{body:JSON.stringify(body)})});
    const result=await response.json();if(!response.ok)throw Object.assign(new Error(result.error||'Request failed'),{status:response.status});return result;
  }
  async signIn(address, signMessage) {
    const challenge=await this.request('/api/auth/challenge',{wallet:address});
    const signature=await signMessage(new TextEncoder().encode(challenge.message));
    const base64=typeof Buffer!=='undefined'?Buffer.from(signature).toString('base64'):btoa(String.fromCharCode(...signature));
    const result=await this.request('/api/auth/verify',{id:challenge.id,signature:base64});this.token=result.token;return result.profile;
  }
  me(){return this.request('/api/me');}
  saveProfile(profile){return this.request('/api/me',profile,'PUT');}
  join(code){return this.request('/api/events/join',{code});}
  advertise(event){return this.request('/api/presence',{event});}
  stopPresence(){return this.request('/api/presence',{},'DELETE');}
  resolve(token){return this.request('/api/discovery/resolve',{token});}
  saveConnection(wallet,note=''){return this.request('/api/connections',{wallet,note},'PUT');}
  connections(){return this.request('/api/connections');}
  block(wallet){return this.request('/api/blocks',{wallet});}
  report(wallet,reason){return this.request('/api/reports',{wallet,reason});}
  createPayment(wallet,amount){return this.request('/api/payments',{wallet,amount});}
  confirmPayment(id,signature){return this.request('/api/payments/confirm',{id,signature});}
}
/** Never manufacture an AR position from BLE RSSI or an expired measurement. */
export function spatialVisibility({worldTransform,measuredAt,status},now=Date.now()) {
  return status==='active'&&Array.isArray(worldTransform)&&worldTransform.length===16&&worldTransform.every(Number.isFinite)&&Number.isFinite(measuredAt)&&now>=measuredAt&&now-measuredAt<=1500;
}
