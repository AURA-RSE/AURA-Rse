import {test} from 'node:test';
import assert from 'node:assert/strict';
import {generateKeyPairSync,sign,randomBytes} from 'node:crypto';
import {mkdtemp,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import bs58 from 'bs58';
import {createAura} from '../server/app.mjs';
function identity(){const k=generateKeyPairSync('ed25519');return {key:k.privateKey,wallet:bs58.encode(k.publicKey.export({format:'der',type:'spki'}).subarray(-32))};}
const draft=(name,status='open')=>({name,role:'Developer',project:'Pilot',bio:'Build something useful',link:'',video:'',intents:['Building'],status});
async function fixture(t,options={}) {
 let time=Date.now();const app=createAura({dbPath:':memory:',clock:()=>time,...options});
 await new Promise(resolve=>app.server.listen(0,'127.0.0.1',resolve));
 t.after(()=>new Promise(resolve=>app.server.close(resolve)));
 const base=`http://127.0.0.1:${app.server.address().port}`;
 const request=async(path,body,token,method=body===undefined?'GET':'POST',headers={})=>{const r=await fetch(base+path,{method,headers:{'Content-Type':'application/json',...(token?{Authorization:`Bearer ${token}`}:{ }),...headers},...(body===undefined?{}:{body:JSON.stringify(body)})});return {status:r.status,...await r.json()};};
 async function login(name='Alice'){const user=identity();const c=await request('/api/auth/challenge',{wallet:user.wallet});const signature=sign(null,Buffer.from(c.message),user.key).toString('base64');const r=await request('/api/auth/verify',{id:c.id,signature});assert.equal(r.status,200);user.token=r.token;await request('/api/me',draft(name),user.token,'PUT');await request('/api/events/join',{code:'AURA-LAB'},user.token);return user;}
 async function discover(a,b){const p=await request('/api/presence',{event:'aura-lab'},b.token);assert.equal(p.status,201);const r=await request('/api/discovery/resolve',{token:p.token},a.token);assert.equal(r.status,200);return p;}
 return {...app,request,login,discover,advance:n=>{time+=n;},base};
}
test('wallet signature required; proof bound to challenge and single-use',async t=>{const f=await fixture(t),a=identity(),b=identity();const c=await f.request('/api/auth/challenge',{wallet:a.wallet});assert.match(c.message,/Origin: http:\/\/localhost:4317/);assert.equal((await f.request('/api/auth/verify',{id:c.id,signature:sign(null,Buffer.from(c.message),b.key).toString('base64')})).status,401);const proof={id:c.id,signature:sign(null,Buffer.from(c.message),a.key).toString('base64')};assert.equal((await f.request('/api/auth/verify',proof)).status,200);assert.equal((await f.request('/api/auth/verify',proof)).status,401);});
test('expired challenges and sessions are rejected',async t=>{const f=await fixture(t),a=identity();const c=await f.request('/api/auth/challenge',{wallet:a.wallet});f.advance(300001);assert.equal((await f.request('/api/auth/verify',{id:c.id,signature:sign(null,Buffer.from(c.message),a.key).toString('base64')})).status,401);const b=await f.login();f.advance(7*86400000+1);assert.equal((await f.request('/api/me',undefined,b.token)).status,401);});
test('profiles cannot be enumerated; event membership and presence required',async t=>{const f=await fixture(t),a=await f.login(),b=await f.login('Bob');assert.equal((await f.request('/api/profiles/read',{wallet:b.wallet},a.token)).status,404);const e=await f.request('/api/events',{name:'Private'},b.token);const p=await f.request('/api/presence',{event:e.id},b.token);assert.equal((await f.request('/api/discovery/resolve',{token:p.token},a.token)).status,404);await f.request('/api/events/join',{code:e.code},a.token);assert.equal((await f.request('/api/discovery/resolve',{token:p.token},a.token)).profile.name,'Bob');});
test('rotation invalidates old token; stealth revokes resolve and unsaved grants',async t=>{const f=await fixture(t),a=await f.login(),b=await f.login('Bob');const old=await f.discover(a,b);const p=await f.request('/api/presence',{event:'aura-lab'},b.token);assert.equal((await f.request('/api/discovery/resolve',{token:old.token},a.token)).status,404);await f.request('/api/me',draft('Bob','stealth'),b.token,'PUT');assert.equal((await f.request('/api/discovery/resolve',{token:p.token},a.token)).status,404);assert.equal((await f.request('/api/profiles/read',{wallet:b.wallet},a.token)).status,404);assert.equal((await f.request('/api/presence',{event:'aura-lab'},b.token)).status,409);});
test('private connections survive presence expiry but notes are not shared',async t=>{const f=await fixture(t),a=await f.login(),b=await f.login('Bob');const p=await f.discover(a,b);await f.request('/api/connections',{wallet:b.wallet,note:'private follow-up'},a.token,'PUT');f.advance(120001);assert.equal((await f.request('/api/discovery/resolve',{token:p.token},a.token)).status,404);await f.request('/api/me',draft('Bob','stealth'),b.token,'PUT');assert.equal((await f.request('/api/presence',{event:'aura-lab'},b.token)).status,409);assert.equal((await f.request('/api/connections',undefined,a.token)).connections[0].note,'private follow-up');assert.equal((await f.request('/api/connections',undefined,b.token)).connections.length,0);assert.equal((await f.request('/api/profiles/read',{wallet:b.wallet},a.token)).status,200);});
test('blocking removes access in both directions including saved connections',async t=>{const f=await fixture(t),a=await f.login(),b=await f.login('Bob');const p=await f.discover(a,b);await f.discover(b,a);await f.request('/api/connections',{wallet:b.wallet,note:''},a.token,'PUT');assert.equal((await f.request('/api/blocks',{wallet:b.wallet},a.token)).status,200);assert.equal((await f.request('/api/profiles/read',{wallet:a.wallet},b.token)).status,404);assert.equal((await f.request('/api/discovery/resolve',{token:p.token},a.token)).status,404);assert.equal((await f.request('/api/connections',undefined,a.token)).connections.length,0);assert.equal((await f.request('/api/payments',{wallet:b.wallet,amount:'0.1'},a.token)).status,404);});
test('device pairing requires authenticated approval; exchange is single-use',async t=>{const f=await fixture(t),a=await f.login();const d=await f.request('/api/device/start',{});assert.equal((await f.request('/api/device/poll',{deviceSecret:d.deviceSecret})).state,'pending');assert.equal((await f.request('/api/device/approve',{code:d.code})).status,401);assert.equal((await f.request('/api/device/approve',{code:d.code},a.token)).status,200);const poll=await f.request('/api/device/poll',{deviceSecret:d.deviceSecret});assert.equal(poll.profile.wallet,a.wallet);assert.ok(poll.token);assert.equal((await f.request('/api/device/poll',{deviceSecret:d.deviceSecret})).status,404);assert.equal(f.db.prepare('SELECT COUNT(*) AS n FROM sessions WHERE hash=?').get(poll.token).n,0);});
test('positioning token relay requires mutual event presence and recipient consent',async t=>{const f=await fixture(t),a=await f.login(),b=await f.login('Bob'),c=await f.login('Carol');await f.discover(a,b);await f.discover(b,a);const r=await f.request('/api/ranging',{wallet:b.wallet,discoveryToken:'dG9rZW4='},a.token);assert.equal(r.status,201);assert.equal((await f.request('/api/ranging',undefined,c.token)).requests.length,0);assert.equal((await f.request('/api/ranging/accept',{id:r.id,discoveryToken:'dG9rZW4='},c.token)).status,404);assert.equal((await f.request('/api/ranging',undefined,a.token)).requests[0].recipient_token,null);assert.equal((await f.request('/api/ranging/accept',{id:r.id,discoveryToken:'cGVlcg=='},b.token)).status,200);await f.request('/api/presence',{},b.token,'DELETE');assert.equal((await f.request('/api/ranging',undefined,a.token)).requests.length,0);});
test('payment verification rejects pending, failed, wrong recipient, and wrong amount',async t=>{let result=null;const f=await fixture(t,{rpc:async()=>result}),a=await f.login(),b=await f.login('Bob');await f.discover(a,b);const p=await f.request('/api/payments',{wallet:b.wallet,amount:'0.000000001'},a.token);assert.equal(p.lamports,1);const signature=bs58.encode(randomBytes(64));const confirm=()=>f.request('/api/payments/confirm',{id:p.id,signature},a.token);assert.equal((await confirm()).state,'pending');result={meta:{err:{failure:true}}};assert.equal((await confirm()).status,409);const instruction={programId:'11111111111111111111111111111111',parsed:{type:'transfer',info:{source:a.wallet,destination:b.wallet,lamports:2}}};result={meta:{err:null},transaction:{message:{accountKeys:[{pubkey:a.wallet,signer:true},{pubkey:p.reference,signer:false}],instructions:[instruction]}}};assert.equal((await confirm()).status,409);instruction.parsed.info.lamports=1;instruction.parsed.info.destination=a.wallet;assert.equal((await confirm()).status,409);instruction.parsed.info.destination=b.wallet;assert.equal((await confirm()).state,'confirmed');assert.equal((await confirm()).signature,signature);assert.equal((await f.request('/api/payments/confirm',{id:p.id,signature},b.token)).status,404);});
test('account export is isolated; deletion cascades; origin and unauthenticated access blocked',async t=>{const f=await fixture(t),a=await f.login(),b=await f.login('Bob');await f.discover(a,b);await f.request('/api/connections',{wallet:b.wallet,note:'private'},a.token,'PUT');assert.equal((await f.request('/api/account/export',undefined,b.token)).connections.length,0);assert.equal((await f.request('/api/me',undefined,a.token,'GET',{Origin:'https://evil.test'})).status,403);assert.equal((await f.request('/api/me')).status,401);assert.equal((await f.request('/api/account',{confirm:'wrong'},a.token,'DELETE')).status,400);assert.equal((await f.request('/api/account',{confirm:'DELETE'},a.token,'DELETE')).status,200);assert.equal((await f.request('/api/me',undefined,a.token)).status,401);assert.equal(f.db.prepare('SELECT COUNT(*) AS n FROM connections').get().n,0);});
test('profile storage persists across process/store reopening',async t=>{const dir=await mkdtemp(join(tmpdir(),'aura-test-'));t.after(()=>rm(dir,{recursive:true,force:true}));const path=join(dir,'aura.sqlite');const app=createAura({dbPath:path});const a=identity();app.db.prepare('INSERT INTO profiles VALUES(?,?,?)').run(a.wallet,JSON.stringify(draft('Durable')),Date.now());app.server.emit('close');const second=createAura({dbPath:path});assert.equal(JSON.parse(second.db.prepare('SELECT data FROM profiles WHERE wallet=?').get(a.wallet).data).name,'Durable');second.server.emit('close');});
test('uploaded media persists privately, supports replacement and deletion',async t=>{const f=await fixture(t),a=await f.login(),b=await f.login('Bob');const data=Buffer.from('89504e470d0a1a0a00000000','hex').toString('base64');const upload=await f.request('/api/media',{kind:'avatar',base64:data},a.token);assert.equal(upload.status,201);assert.equal((await f.request('/api/me',undefined,a.token)).profile.avatarMediaId,upload.id);const denied=await fetch(f.base+'/api/media/'+upload.id,{headers:{Authorization:`Bearer ${b.token}`}});assert.equal(denied.status,404);await f.discover(b,a);const allowed=await fetch(f.base+'/api/media/'+upload.id,{headers:{Authorization:`Bearer ${b.token}`}});assert.equal(allowed.status,200);assert.equal(Buffer.from(await allowed.arrayBuffer()).toString('base64'),data);await f.request('/api/me',draft('Alice updated'),a.token,'PUT');assert.equal((await f.request('/api/me',undefined,a.token)).profile.avatarMediaId,upload.id);assert.equal((await f.request('/api/media',{kind:'avatar',base64:Buffer.from('<script>').toString('base64')},a.token)).status,400);await f.request('/api/media',{kind:'avatar'},a.token,'DELETE');assert.equal(f.db.prepare('SELECT COUNT(*) AS n FROM media').get().n,0);});
test('malformed payment signature returns a client error',async t=>{const f=await fixture(t),a=await f.login(),b=await f.login('Bob');await f.discover(a,b);const p=await f.request('/api/payments',{wallet:b.wallet,amount:'0.1'},a.token);assert.equal((await f.request('/api/payments/confirm',{id:p.id,signature:'not a signature'},a.token)).status,400);});
test('signed payment persists before uncertain RPC and cannot be submitted twice',async t=>{
 const {Keypair,PublicKey,Transaction,SystemProgram}=await import('@solana/web3.js');let sent=0;
 const f=await fixture(t,{rpc:async()=>{sent++;throw new Error('timeout');}}),a=await f.login(),b=await f.login('Bob');await f.discover(a,b);
 const p=await f.request('/api/payments',{wallet:b.wallet,amount:'0.1'},a.token);
 const keypair=Keypair.fromSeed(a.key.export({format:'der',type:'pkcs8'}).subarray(-32));
 const transaction=new Transaction({feePayer:keypair.publicKey,recentBlockhash:bs58.encode(randomBytes(32))});const i=SystemProgram.transfer({fromPubkey:keypair.publicKey,toPubkey:new PublicKey(b.wallet),lamports:p.lamports});i.keys.push({pubkey:new PublicKey(p.reference),isSigner:false,isWritable:false});transaction.add(i);transaction.sign(keypair);
 const body={id:p.id,transaction:transaction.serialize().toString('base64')};const first=await f.request('/api/payments/submit',body,a.token);assert.equal(first.state,'uncertain');assert.equal(first.signature,bs58.encode(transaction.signature));
 assert.equal((await f.request('/api/payments/submit',body,a.token)).state,'submitted');assert.equal(sent,1);assert.equal((await f.request('/api/payments',undefined,a.token)).payments[0].submitted_signature,first.signature);
});
test('signed transaction changing the reviewed amount is rejected before RPC',async t=>{
 const {Keypair,PublicKey,Transaction,SystemProgram}=await import('@solana/web3.js');let sent=0;
 const f=await fixture(t,{rpc:async()=>{sent++;}}),a=await f.login(),b=await f.login('Bob');await f.discover(a,b);const p=await f.request('/api/payments',{wallet:b.wallet,amount:'0.1'},a.token);
 const k=Keypair.fromSeed(a.key.export({format:'der',type:'pkcs8'}).subarray(-32));const tx=new Transaction({feePayer:k.publicKey,recentBlockhash:bs58.encode(randomBytes(32))});const i=SystemProgram.transfer({fromPubkey:k.publicKey,toPubkey:new PublicKey(b.wallet),lamports:p.lamports+1});i.keys.push({pubkey:new PublicKey(p.reference),isSigner:false,isWritable:false});tx.add(i);tx.sign(k);
 assert.equal((await f.request('/api/payments/submit',{id:p.id,transaction:tx.serialize().toString('base64')},a.token)).status,409);assert.equal(sent,0);
});
test('backup command produces a restorable SQLite snapshot',async t=>{const {execFileSync}=await import('node:child_process');const dir=await mkdtemp(join(tmpdir(),'aura-backup-'));t.after(()=>rm(dir,{recursive:true,force:true}));const source=join(dir,'source.sqlite'),target=join(dir,'backup.sqlite');const app=createAura({dbPath:source});const user=identity();app.db.prepare('INSERT INTO profiles VALUES(?,?,?)').run(user.wallet,JSON.stringify(draft('Backup proof')),Date.now());execFileSync(process.execPath,['scripts/backup.mjs',target],{env:{...process.env,AURA_DB:source}});app.server.emit('close');const restored=createAura({dbPath:target});assert.equal(JSON.parse(restored.db.prepare('SELECT data FROM profiles WHERE wallet=?').get(user.wallet).data).name,'Backup proof');restored.server.emit('close');});
test('cleanup preserves unresolved submitted signatures for recovery',async t=>{const f=await fixture(t),a=await f.login(),b=await f.login('Bob');await f.discover(a,b);const pending=await f.request('/api/payments',{wallet:b.wallet,amount:'0.1'},a.token);const abandoned=await f.request('/api/payments',{wallet:b.wallet,amount:'0.2'},a.token);const signature=bs58.encode(randomBytes(64));f.db.prepare('UPDATE payments SET submitted_signature=? WHERE id=?').run(signature,pending.id);f.advance(2*86400000);f.sweep();const kept=f.db.prepare('SELECT submitted_signature FROM payments WHERE id=?').get(pending.id);assert.equal(kept.submitted_signature,signature);assert.equal(f.db.prepare('SELECT id FROM payments WHERE id=?').get(abandoned.id),undefined);});
test('native payment preparation fixes sender, recipient, amount and reference in one unsigned transfer',async t=>{
 const {Transaction,SystemInstruction,Keypair}=await import('@solana/web3.js');let submissions=0;
 const f=await fixture(t,{rpc:async(method)=>{if(method==='getLatestBlockhash')return {value:{blockhash:bs58.encode(randomBytes(32)),lastValidBlockHeight:12345}};if(method==='sendTransaction'){submissions++;return;}throw Error('Unexpected RPC');}});
 const a=await f.login(),b=await f.login('Bob');await f.discover(a,b);
 const p=await f.request('/api/payments',{wallet:b.wallet,amount:'0.000000001'},a.token);
 assert.equal((await f.request('/api/payments/prepare',{id:p.id},b.token)).status,404);
 const prepared=await f.request('/api/payments/prepare',{id:p.id,recipient:a.wallet,lamports:999},a.token);assert.equal(prepared.status,200);assert.equal(prepared.cluster,'devnet');assert.equal(prepared.lastValidBlockHeight,12345);
 const tx=Transaction.from(Buffer.from(prepared.transaction,'base64'));assert.equal(tx.feePayer.toBase58(),a.wallet);assert.equal(tx.instructions.length,1);assert.equal(tx.signature,null);
 const transfer=SystemInstruction.decodeTransfer(tx.instructions[0]);assert.equal(transfer.toPubkey.toBase58(),b.wallet);assert.equal(transfer.lamports,1n);assert.equal(tx.instructions[0].keys[2].pubkey.toBase58(),p.reference);assert.equal(tx.instructions[0].keys[2].isWritable,false);
 tx.sign(Keypair.fromSeed(a.key.export({format:'der',type:'pkcs8'}).subarray(-32)));
 const sent=await f.request('/api/payments/submit',{id:p.id,transaction:tx.serialize().toString('base64')},a.token);assert.equal(sent.state,'submitted');assert.equal(submissions,1);
 assert.equal((await f.request('/api/payments/prepare',{id:p.id},a.token)).status,409);
});
test('native payment preparation rechecks expiry and blocking after blockhash lookup',async t=>{
 let duringRPC=()=>{};const f=await fixture(t,{rpc:async()=>{await duringRPC();return {value:{blockhash:bs58.encode(randomBytes(32)),lastValidBlockHeight:123}};}});
 const a=await f.login(),b=await f.login('Bob');await f.discover(a,b);
 let p=await f.request('/api/payments',{wallet:b.wallet,amount:'0.1'},a.token);
 duringRPC=()=>f.advance(600001);assert.equal((await f.request('/api/payments/prepare',{id:p.id},a.token)).status,409);
 await f.discover(a,b);p=await f.request('/api/payments',{wallet:b.wallet,amount:'0.1'},a.token);
 duringRPC=()=>f.request('/api/blocks',{wallet:b.wallet},a.token);assert.equal((await f.request('/api/payments/prepare',{id:p.id},a.token)).status,404);
});
test('native payment preparation rejects invalid upstream blockhash response without signing or submission',async t=>{
 let value={blockhash:'bad',lastValidBlockHeight:1};const f=await fixture(t,{rpc:async()=>({value})}),a=await f.login(),b=await f.login('Bob');await f.discover(a,b);
 const p=await f.request('/api/payments',{wallet:b.wallet,amount:'0.1'},a.token);
 assert.equal((await f.request('/api/payments/prepare',{id:p.id},a.token)).status,502);
 value={blockhash:bs58.encode(randomBytes(32)),lastValidBlockHeight:-1};assert.equal((await f.request('/api/payments/prepare',{id:p.id},a.token)).status,502);
 assert.equal(f.db.prepare('SELECT submitted_signature FROM payments WHERE id=?').get(p.id).submitted_signature,null);
});


test('reports survive target deletion and detach a deleted reporter without exposing reports to others', async t => {
 const f=await fixture(t),a=await f.login(),b=await f.login('Bob'),c=await f.login('Carol');
 assert.equal((await f.request('/api/reports',{wallet:b.wallet,reason:'Unknown participant'},a.token)).status,404);
 await f.discover(a,b);
 const result=await f.request('/api/reports',{wallet:b.wallet,reason:'Repeated unwanted contact'},a.token);
 assert.equal(result.status,201);
 const initial=f.db.prepare('SELECT * FROM reports').get();
 assert.equal(result.expires,initial.created+90*86400000);
 assert.equal((await f.request('/api/account/export',undefined,b.token)).reports.length,0);
 assert.equal((await f.request('/api/account/export',undefined,c.token)).reports.length,0);
 assert.equal((await f.request('/api/account',{confirm:'DELETE'},b.token,'DELETE')).status,200);
 const exported=(await f.request('/api/account/export',undefined,a.token)).reports;
 assert.equal(exported.length,1);assert.equal(exported[0].target,b.wallet);
 assert.equal(exported[0].expires,initial.expires);
 assert.equal((await f.request('/api/account',{confirm:'DELETE'},a.token,'DELETE')).status,200);
 const retained=f.db.prepare('SELECT * FROM reports').get();
 assert.equal(retained.owner,null);assert.equal(retained.target,b.wallet);
 assert.equal(retained.reason,initial.reason);assert.equal(retained.expires,initial.expires);
 assert.equal(f.db.prepare('SELECT COUNT(*) AS n FROM sessions WHERE wallet IN (?,?)').get(a.wallet,b.wallet).n,0);
 const challenge=await f.request('/api/auth/challenge',{wallet:a.wallet});
 const again=await f.request('/api/auth/verify',{id:challenge.id,signature:sign(null,Buffer.from(challenge.message),a.key).toString('base64')});
 assert.equal((await f.request('/api/account/export',undefined,again.token)).reports.length,0);
 assert.equal(f.db.prepare('SELECT owner FROM reports').get().owner,null);
 assert.deepEqual(f.db.prepare('PRAGMA foreign_key_check').all(),[]);
});

test('reports expire at the original deadline and are hidden from export before the next sweep', async t => {
 const f=await fixture(t),a=await f.login(),b=await f.login('Bob');await f.discover(a,b);
 await f.request('/api/reports',{wallet:b.wallet,reason:'A bounded incident record'},a.token);
 f.advance(90*86400000-1);f.sweep();
 assert.equal(f.db.prepare('SELECT COUNT(*) AS n FROM reports').get().n,1);
 const challenge=await f.request('/api/auth/challenge',{wallet:a.wallet});
 const again=await f.request('/api/auth/verify',{id:challenge.id,signature:sign(null,Buffer.from(challenge.message),a.key).toString('base64')});
 assert.equal((await f.request('/api/account/export',undefined,again.token)).reports.length,1);
 f.advance(1);
 assert.equal((await f.request('/api/account/export',undefined,again.token)).reports.length,0);
 f.sweep();assert.equal(f.db.prepare('SELECT COUNT(*) AS n FROM reports').get().n,0);
});

test('recipient deletion preserves another sender payment history but removes profile and media', async t => {
 const f=await fixture(t),a=await f.login(),b=await f.login('Bob');await f.discover(a,b);
 await f.request('/api/connections',{wallet:b.wallet,note:'Delete this connection'},a.token,'PUT');
 await f.request('/api/media',{kind:'avatar',base64:Buffer.from('89504e470d0a1a0a00000000','hex').toString('base64')},b.token);
 const payment=await f.request('/api/payments',{wallet:b.wallet,amount:'0.1'},a.token);
 const signature=bs58.encode(randomBytes(64));
 f.db.prepare('UPDATE payments SET submitted_signature=? WHERE id=?').run(signature,payment.id);
 assert.equal((await f.request('/api/account',{confirm:'DELETE'},b.token,'DELETE')).status,200);
 const history=(await f.request('/api/payments',undefined,a.token)).payments;
 assert.equal(history.length,1);assert.equal(history[0].recipient,b.wallet);assert.equal(history[0].submitted_signature,signature);
 assert.equal(f.db.prepare('SELECT COUNT(*) AS n FROM media').get().n,0);
 assert.equal(f.db.prepare('SELECT COUNT(*) AS n FROM connections').get().n,0);
 assert.equal((await f.request('/api/profiles/read',{wallet:b.wallet},a.token)).status,404);
 assert.equal((await f.request('/api/account',{confirm:'DELETE'},a.token,'DELETE')).status,200);
 assert.equal(f.db.prepare('SELECT COUNT(*) AS n FROM payments').get().n,0);
});


test('event directory requires membership and explicit opt-in without Bluetooth presence',async t=>{
 const f=await fixture(t),a=await f.login(),b=await f.login('Bob'),c=await f.login('Carol');
 const list=(user,event='aura-lab')=>f.request('/api/events/people',{event},user.token);
 assert.equal((await f.request('/api/events/people',{event:'aura-lab'})).status,401);
 assert.deepEqual((await list(a)).profiles,[]);
 const privateEvent=await f.request('/api/events',{name:'Private room'},c.token);
 assert.equal((await list(a,privateEvent.id)).status,403);
 assert.equal((await f.request('/api/me',{...draft('Bob'),eventDirectory:'true'},b.token,'PUT')).status,400);
 await f.request('/api/me',{...draft('Bob'),eventDirectory:true},b.token,'PUT');
 assert.deepEqual((await list(a)).profiles.map(p=>p.wallet),[b.wallet]);
 assert.deepEqual((await list(b)).profiles,[]); // Never list yourself.
 assert.equal(f.db.prepare('SELECT COUNT(*) AS n FROM presence').get().n,0);
 assert.equal((await f.request('/api/profiles/read',{wallet:b.wallet},a.token)).status,200);
 const media=await f.request('/api/media',{kind:'avatar',base64:Buffer.from('89504e470d0a1a0a00000000','hex').toString('base64')},b.token);
 const mediaStatus=async()=> (await fetch(f.base+'/api/media/'+media.id,{headers:{Authorization:'Bearer '+a.token}})).status;
 assert.equal(await mediaStatus(),200);
 await f.request('/api/me',{...draft('Bob'),eventDirectory:false},b.token,'PUT');
 assert.deepEqual((await list(a)).profiles,[]);
 assert.equal((await f.request('/api/profiles/read',{wallet:b.wallet},a.token)).status,404);
 assert.equal(await mediaStatus(),404);
 assert.equal((await f.request('/api/connections',{wallet:b.wallet,note:''},a.token,'PUT')).status,404);
});

test('directory honors stealth, blocks and event leaving while saved connections remain durable',async t=>{
 const f=await fixture(t),a=await f.login(),b=await f.login('Bob');
 const list=user=>f.request('/api/events/people',{event:'aura-lab'},user.token);
 const visible=async(status='open')=>f.request('/api/me',{...draft('Bob',status),eventDirectory:true},b.token,'PUT');
 await visible();await f.request('/api/me',draft('Bob updated'),b.token,'PUT');
 assert.equal((await list(a)).profiles.length,1); // Older clients preserve explicit opt-in.
 await visible('stealth');assert.equal((await list(a)).profiles.length,0);
 assert.equal((await f.request('/api/profiles/read',{wallet:b.wallet},a.token)).status,404);
 await visible();await f.request('/api/events/leave',{event:'aura-lab'},a.token);
 assert.equal((await list(a)).status,403);
 assert.equal((await f.request('/api/profiles/read',{wallet:b.wallet},a.token)).status,404);
 await f.request('/api/events/join',{code:'AURA-LAB'},a.token);
 assert.equal((await f.request('/api/connections',{wallet:b.wallet,note:'Keep in touch'},a.token,'PUT')).status,200);
 await f.request('/api/events/leave',{event:'aura-lab'},b.token);
 assert.equal((await list(a)).profiles.length,0);
 assert.equal((await f.request('/api/connections',undefined,a.token)).connections.length,1);
 await f.request('/api/events/join',{code:'AURA-LAB'},b.token);
 await f.request('/api/blocks',{wallet:b.wallet},a.token);
 assert.equal((await list(a)).profiles.length,0);
 assert.equal((await list(b)).profiles.length,0);
 assert.equal((await f.request('/api/profiles/read',{wallet:b.wallet},a.token)).status,404);
 assert.equal((await f.request('/api/connections',undefined,a.token)).connections.length,0);
});
