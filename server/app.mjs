import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { resolve, extname } from 'node:path';
import { randomBytes } from 'node:crypto';
import { openStore, REPORT_RETENTION_MS, SCHEMA_VERSION } from './store.mjs';
import { HttpError, fail, secret, hash, wallet, text, verifyWallet, profileInput, lamports } from './core.mjs';
import bs58 from 'bs58';
import { Transaction, SystemInstruction, SystemProgram, PublicKey } from '@solana/web3.js';

export function createAura({dbPath = 'data/aura.sqlite', origin = 'http://localhost:4317', staticDir = 'dist', clock = Date.now, rpc: customRPC} = {}) {
  const db = openStore(dbPath); const now = () => clock();
  const get = (sql,...args) => db.prepare(sql).get(...args);
  const all = (sql,...args) => db.prepare(sql).all(...args);
  const run = (sql,...args) => db.prepare(sql).run(...args);
  run('INSERT OR IGNORE INTO events VALUES(?,?,?,?,?)','aura-lab',null,'Aura Local Lab','AURA-LAB',now());
  const limits = new Map();
  const rpc = customRPC || (async (method,params) => {
    const response = await fetch('https://api.devnet.solana.com', {method:'POST', headers:{'Content-Type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:1,method,params}),signal:AbortSignal.timeout(12000)});
    if (!response.ok) fail(502,'Devnet RPC unavailable');
    const data = await response.json(); if(data.error) fail(502, 'Devnet RPC rejected the request'); return data.result;
  });
  const profile = w => { const row = get('SELECT * FROM profiles WHERE wallet=?',w); return row && {...JSON.parse(row.data),wallet:w,updated:row.updated}; };
  const blocked = (a,b) => get('SELECT 1 FROM blocks WHERE (owner=? AND target=?) OR (owner=? AND target=?)',a,b,b,a);
  const directoryVisible = (a,b) => { const p=profile(b);return p?.eventDirectory === true && p.status !== 'stealth' && get('SELECT 1 FROM members a JOIN members b ON a.event=b.event WHERE a.wallet=? AND b.wallet=? LIMIT 1',a,b); };
  const canRead = (a,b) => a===b || (!blocked(a,b) && (directoryVisible(a,b) || get('SELECT 1 FROM access WHERE viewer=? AND target=? AND expires>?',a,b,now()) || get('SELECT 1 FROM connections WHERE owner=? AND target=?',a,b)));
  const rangingPresence = (a,b) => {
    const first=get('SELECT * FROM presence WHERE wallet=? AND expires>?',a,now());
    const second=get('SELECT * FROM presence WHERE wallet=? AND expires>?',b,now());
    return first && second && first.event===second.event && first.ranging_protocol==='apple-ni-v2' && second.ranging_protocol==='apple-ni-v2'
      && !blocked(a,b) && profile(a)?.status!=='stealth' && profile(b)?.status!=='stealth';
  };
  const session = w => {const token=secret(); run('INSERT INTO sessions VALUES(?,?,?)',hash(token),w,now()+7*86400000); return token;};
  const revokePresence = w => {run('DELETE FROM presence WHERE wallet=?',w);run('DELETE FROM access WHERE target=?',w);run('DELETE FROM ranging WHERE sender=? OR recipient=?',w,w);};
  const sweep = () => {for(const table of ['challenges','sessions','presence','access','devices','ranging','reports']) run(`DELETE FROM ${table} WHERE expires<=?`,now()); run('DELETE FROM payments WHERE signature IS NULL AND submitted_signature IS NULL AND expires<?',now()-86400000);};
  sweep(); // Apply retention before serving requests, including after a backup restore.
  const interval=setInterval(sweep,30000);interval.unref();
  const server = createServer(async (req,res) => {
    const respond=(status,data)=>{res.writeHead(status,{'Content-Type':'application/json'});res.end(JSON.stringify(data));};
    try {
      res.setHeader('Cache-Control','no-store'); res.setHeader('X-Content-Type-Options','nosniff'); res.setHeader('Referrer-Policy','no-referrer');
      res.setHeader('Content-Security-Policy',"default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data: blob:; media-src 'self' blob:; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'");
      if(req.headers.origin && req.headers.origin!==origin) fail(403,'Origin not allowed');
      const path=new URL(req.url,'http://local').pathname;
      const api=path.startsWith('/api/') || path==='/rpc';
      if(!api) {
        if(req.method!=='GET') fail(405,'Method not allowed');
        const allowed={'/':'index.html','/app.js':'app.js','/style.css':'style.css'};
        if(!allowed[path]) fail(404,'Not found');
        const file=resolve(staticDir,allowed[path]); const data=await readFile(file);
        res.writeHead(200,{'Content-Type':{'.html':'text/html; charset=utf-8','.js':'text/javascript','.css':'text/css'}[extname(file)]});res.end(data);return;
      }
      const ip=req.socket.remoteAddress;const slot=Math.floor(now()/60000);
      const presented=req.headers.authorization?.match(/^Bearer ([A-Za-z0-9_-]{43})$/)?.[1];
      const verified=presented&&get('SELECT 1 FROM sessions WHERE hash=? AND expires>?',hash(presented),now());
      const key=(verified?hash(presented):ip)+':'+slot;
      for(const oldKey of limits.keys())if(!oldKey.endsWith(':'+slot))limits.delete(oldKey);
      limits.set(key,(limits.get(key)||0)+1);
      if(limits.get(key)>(verified?1800:120)) fail(429,'Too many requests; try again shortly');
      if(path==='/api/health' && req.method==='GET') return respond(200,{status:'ok',version:'0.3.0',cluster:'devnet',schemaVersion:SCHEMA_VERSION});
      let body={};
      if(['POST','PUT','DELETE'].includes(req.method)) {
        let size=0;const chunks=[];for await(const chunk of req){size+=chunk.length;if(size>(path==='/api/media'?29*1024*1024:16384))fail(413,'Request too large');chunks.push(chunk);}
        try {body=chunks.length?JSON.parse(Buffer.concat(chunks).toString()):{};}catch{fail(400,'Invalid JSON');}
        if(!body||typeof body!=='object'||Array.isArray(body))fail(400,'Expected an object');
      }
      const route=req.method+' '+path;
      if(route==='POST /api/auth/challenge') {
        const address=wallet(body.wallet); const id=secret(); const expires=now()+5*60000;
        const message=`Aura wallet verification\nOrigin: ${origin}\nWallet: ${address}\nNonce: ${id}\nExpires: ${new Date(expires).toISOString()}\n\nSign in to Aura. This does not authorize a transaction.`;
        run('INSERT INTO challenges VALUES(?,?,?,?)',id,address,message,expires);return respond(201,{id,message,expires});
      }
      if(route==='POST /api/auth/verify') {
        const c=get('SELECT * FROM challenges WHERE id=?',text(body.id,100,true));
        if(!c || c.expires<=now() || !verifyWallet(c.wallet,c.message,body.signature))fail(401,'Invalid or expired wallet proof');
        run('DELETE FROM challenges WHERE id=?',c.id);
        const initial={name:'',role:'',project:'',bio:'',link:'',video:'',intents:[],status:'stealth'};
        run('INSERT OR IGNORE INTO profiles VALUES(?,?,?)',c.wallet,JSON.stringify(initial),now());
        return respond(200,{token:session(c.wallet),profile:profile(c.wallet)});
      }
      if(route==='POST /api/device/start') {
        const deviceSecret=secret(); const code=randomBytes(5).toString('hex').toUpperCase();const expires=now()+5*60000;
        run('INSERT INTO devices VALUES(?,?,?,?)',hash(deviceSecret),code,null,expires);return respond(201,{deviceSecret,code,expires});
      }
      if(route==='POST /api/device/poll') {
        const device=get('SELECT * FROM devices WHERE hash=? AND expires>?',hash(text(body.deviceSecret,100,true)),now());
        if(!device)fail(404,'Device request expired');if(!device.wallet)return respond(200,{state:'pending'});
        run('DELETE FROM devices WHERE hash=?',device.hash);return respond(200,{state:'approved',token:session(device.wallet),profile:profile(device.wallet)});
      }
      const auth=req.headers.authorization?.match(/^Bearer ([A-Za-z0-9_-]{43})$/)?.[1];
      const user=auth&&get('SELECT wallet FROM sessions WHERE hash=? AND expires>?',hash(auth),now());
      if(!user)fail(401,'Connect and verify your wallet');const me=user.wallet;
      if(route==='POST /api/auth/logout'){run('DELETE FROM sessions WHERE hash=?',hash(auth));revokePresence(me);return respond(200,{ok:true});}
      if(route==='GET /api/me')return respond(200,{profile:profile(me)});
      if(route==='PUT /api/me') {
        const input=profileInput(body);const old=profile(me);const p={...input,eventDirectory:body.eventDirectory === undefined ? old.eventDirectory === true : input.eventDirectory,avatarMediaId:old.avatarMediaId||null,videoMediaId:old.videoMediaId||null};run('UPDATE profiles SET data=?,updated=? WHERE wallet=?',JSON.stringify(p),now(),me);
        if(p.status==='stealth')revokePresence(me);return respond(200,{profile:profile(me)});
      }
      if(route==='POST /api/device/approve') {
        const code=text(body.code,10,true).toUpperCase();
        const result=run('UPDATE devices SET wallet=? WHERE code=? AND wallet IS NULL AND expires>?',me,code,now());
        if(!result.changes)fail(404,'Pairing code expired or already used');return respond(200,{ok:true});
      }
      if(route==='GET /api/events')return respond(200,{events:all('SELECT e.id,e.name,e.owner FROM events e JOIN members m ON e.id=m.event WHERE m.wallet=?',me)});
      if(route==='POST /api/events/people') {
        const event=text(body.event,100,true);
        if(!get('SELECT 1 FROM members WHERE event=? AND wallet=?',event,me))fail(403,'Join this event first');
        const profiles=all('SELECT p.wallet,p.data,p.updated FROM profiles p JOIN members m ON p.wallet=m.wallet WHERE m.event=? AND p.wallet!=?',event,me)
          .filter(row=>!blocked(me,row.wallet)).map(row=>({...JSON.parse(row.data),wallet:row.wallet,updated:row.updated}))
          .filter(p=>p.eventDirectory===true && p.status!=='stealth')
          .sort((a,b)=>a.name.localeCompare(b.name)||a.wallet.localeCompare(b.wallet));
        return respond(200,{event,profiles});
      }
      if(route==='POST /api/events') {
        const id=secret(12),code=randomBytes(5).toString('hex').toUpperCase();
        run('INSERT INTO events VALUES(?,?,?,?,?)',id,me,text(body.name,100,true),code,now());run('INSERT INTO members VALUES(?,?)',id,me);return respond(201,{id,code});
      }
      if(route==='POST /api/events/join') {
        const event=get('SELECT id,name FROM events WHERE code=?',text(body.code,40,true).toUpperCase());if(!event)fail(404,'Event code not found');
        run('INSERT OR IGNORE INTO members VALUES(?,?)',event.id,me);return respond(200,{event});
      }
      if(route==='POST /api/events/leave') {
        const event=text(body.event,100,true);run('DELETE FROM members WHERE event=? AND wallet=?',event,me);revokePresence(me);return respond(200,{ok:true});
      }
      if(route==='POST /api/presence') {
        const p=profile(me);if(!p.name||p.status==='stealth')fail(409,'Complete your profile and choose a discoverable status first');
        const event=text(body.event,100,true);if(!get('SELECT 1 FROM members WHERE event=? AND wallet=?',event,me))fail(403,'Join this event first');
        const token=secret(16),expires=now()+90000;
        const protocol=body.rangingProtocol ?? '';
        if(!['','apple-ni-v2'].includes(protocol))fail(400,'Unsupported positioning protocol');
        if(body.resetRanging!==undefined && typeof body.resetRanging!=='boolean')fail(400,'Invalid positioning reset');
        if(body.resetRanging===true)run('DELETE FROM ranging WHERE sender=? OR recipient=?',me,me);
        const previous=get('SELECT event,ranging_protocol FROM presence WHERE wallet=?',me);
        if(previous && (previous.event!==event || previous.ranging_protocol!==protocol))revokePresence(me);
        run('DELETE FROM presence WHERE wallet=?',me);run('INSERT INTO presence(hash,wallet,event,expires,ranging_protocol) VALUES(?,?,?,?,?)',hash(token),me,event,expires,protocol);
        return respond(201,{token,expires,event});
      }
      if(route==='DELETE /api/presence'){revokePresence(me);return respond(200,{ok:true});}
      if(route==='POST /api/discovery/resolve') {
        const p=get('SELECT * FROM presence WHERE hash=? AND expires>?',hash(text(body.token,100,true)),now());
        if(!p || p.wallet===me || blocked(me,p.wallet) || !get('SELECT 1 FROM members WHERE event=? AND wallet=?',p.event,me))fail(404,'Presence unavailable');
        const target=profile(p.wallet);if(target.status==='stealth')fail(404,'Presence unavailable');
        run('INSERT INTO access VALUES(?,?,?) ON CONFLICT(viewer,target) DO UPDATE SET expires=excluded.expires',me,p.wallet,now()+120000);
        return respond(200,{profile:target,event:p.event,expires:p.expires,rangingProtocol:p.ranging_protocol});
      }
      if(route==='POST /api/profiles/read') {
        const target=wallet(body.wallet);if(!canRead(me,target))fail(404,'Profile unavailable');return respond(200,{profile:profile(target)});
      }
      if(route==='GET /api/connections')return respond(200,{connections:all('SELECT target,note,created FROM connections WHERE owner=? ORDER BY created DESC',me).filter(c=>!blocked(me,c.target)).map(c=>({...c,profile:profile(c.target)}))});
      if(route==='PUT /api/connections') {
        const target=wallet(body.wallet);if(target===me||!canRead(me,target))fail(404,'Discover this participant first');
        run('INSERT INTO connections VALUES(?,?,?,?) ON CONFLICT(owner,target) DO UPDATE SET note=excluded.note',me,target,text(body.note||'',1000),now());return respond(200,{ok:true});
      }
      if(route==='DELETE /api/connections'){run('DELETE FROM connections WHERE owner=? AND target=?',me,wallet(body.wallet));return respond(200,{ok:true});}
      if(route==='POST /api/blocks') {
        const target=wallet(body.wallet);if(target===me||!canRead(me,target))fail(404,'Participant unavailable');
        run('INSERT OR IGNORE INTO blocks VALUES(?,?)',me,target);
        run('DELETE FROM access WHERE (viewer=? AND target=?) OR (viewer=? AND target=?)',me,target,target,me);
        run('DELETE FROM ranging WHERE (sender=? AND recipient=?) OR (sender=? AND recipient=?)',me,target,target,me);return respond(200,{ok:true});
      }
      if(route==='GET /api/blocks')return respond(200,{blocks:all('SELECT target FROM blocks WHERE owner=?',me)});
      if(route==='DELETE /api/blocks'){run('DELETE FROM blocks WHERE owner=? AND target=?',me,wallet(body.wallet));return respond(200,{ok:true});}
      if(route==='POST /api/reports') {
        const target=wallet(body.wallet);if(target===me||!canRead(me,target))fail(404,'Participant unavailable');
        const created=now(),expires=created+REPORT_RETENTION_MS;
        run('INSERT INTO reports(id,owner,target,reason,created,expires) VALUES(?,?,?,?,?,?)',secret(),me,target,text(body.reason,1000,true),created,expires);
        return respond(201,{ok:true,expires,message:'Report stored for operator review for 90 days, including after account deletion. No automated moderation is claimed.'});
      }
      if(route==='POST /api/ranging') {
        const target=wallet(body.wallet);if(target===me||!canRead(me,target))fail(404,'Participant unavailable');
        if(!rangingPresence(me,target))fail(409,'Both phones must support Apple positioning and be present in the same event');
        if(get('SELECT 1 FROM ranging WHERE ((sender=? AND recipient=?) OR (sender=? AND recipient=?)) AND expires>?',me,target,target,me,now()))fail(409,'Positioning with this participant is already requested');
        for(const participant of [me,target])if(get('SELECT COUNT(*) AS n FROM ranging WHERE (sender=? OR recipient=?) AND expires>?',participant,participant,now()).n>=3)fail(409,'Three positioning requests are already active. Stop one before adding another.');
        const token=text(body.discoveryToken,4096,true);if(!/^[A-Za-z0-9+/]+=*$/.test(token))fail(400,'Invalid discovery token');
        const id=secret(12);run('INSERT INTO ranging VALUES(?,?,?,?,?,?)',id,me,target,token,null,now()+120000);return respond(201,{id});
      }
      if(route==='GET /api/ranging')return respond(200,{requests:all('SELECT * FROM ranging WHERE (sender=? OR recipient=?) AND expires>?',me,me,now()).filter(r=>rangingPresence(r.sender,r.recipient)).map(r=>({...r,peer:profile(r.sender===me?r.recipient:r.sender)}))});
      if(route==='POST /api/ranging/accept') {
        const id=text(body.id,100,true),token=text(body.discoveryToken,4096,true);if(!/^[A-Za-z0-9+/]+=*$/.test(token))fail(400,'Invalid discovery token');
        const pending=get('SELECT * FROM ranging WHERE id=? AND recipient=? AND recipient_token IS NULL AND expires>?',id,me,now());
        if(!pending || !rangingPresence(pending.sender,me))fail(404,'Positioning request unavailable');
        const result=run('UPDATE ranging SET recipient_token=? WHERE id=? AND recipient=? AND recipient_token IS NULL AND expires>?',token,id,me,now());if(!result.changes)fail(404,'Positioning request expired');return respond(200,{ok:true});
      }
      if(route==='DELETE /api/ranging'){run('DELETE FROM ranging WHERE id=? AND (sender=? OR recipient=?)',text(body.id,100,true),me,me);return respond(200,{ok:true});}
      if(route==='POST /api/payments') {
        const recipient=wallet(body.wallet);if(recipient===me||!canRead(me,recipient))fail(404,'Discover the recipient first');
        const id=secret(12),amount=lamports(body.amount),reference=bs58.encode(randomBytes(32));const expires=now()+600000;
        run('INSERT INTO payments(id,sender,recipient,lamports,reference,signature,expires,created) VALUES(?,?,?,?,?,?,?,?)',id,me,recipient,amount,reference,null,expires,now());return respond(201,{id,sender:me,recipient,lamports:amount,reference,cluster:'devnet',expires});
      }
      if(route==='POST /api/payments/prepare') {
        const id=text(body.id,100,true);
        const load=()=>{const p=get('SELECT * FROM payments WHERE id=? AND sender=?',id,me);
          if(!p)fail(404,'Payment not found');
          if(p.signature||p.submitted_signature)fail(409,'Payment already submitted; check its signature');
          if(p.expires<=now())fail(409,'Payment review expired');
          if(!canRead(me,p.recipient))fail(404,'Recipient unavailable');
          return p;};
        load();
        const latest=await rpc('getLatestBlockhash',[{commitment:'confirmed'}]);
        // Recheck after network I/O: hide/block, expiry or another submission can happen meanwhile.
        const p=load();const value=latest?.value;
        if(!value||typeof value.blockhash!=='string'||!Number.isSafeInteger(value.lastValidBlockHeight)||value.lastValidBlockHeight<0)fail(502,'Invalid blockhash response');
        let transaction;
        try {
          const blockhash=new PublicKey(value.blockhash).toBase58();
          const tx=new Transaction({feePayer:new PublicKey(me),recentBlockhash:blockhash});
          const instruction=SystemProgram.transfer({fromPubkey:new PublicKey(me),toPubkey:new PublicKey(p.recipient),lamports:p.lamports});
          instruction.keys.push({pubkey:new PublicKey(p.reference),isSigner:false,isWritable:false});tx.add(instruction);
          transaction=tx.serialize({requireAllSignatures:false,verifySignatures:false}).toString('base64');
        } catch { fail(502,'Invalid blockhash response'); }
        return respond(200,{...p,cluster:'devnet',transaction,lastValidBlockHeight:value.lastValidBlockHeight});
      }
      if(route==='POST /api/payments/submit') {
        const p=get('SELECT * FROM payments WHERE id=? AND sender=?',text(body.id,100,true),me);
        if(!p)fail(404,'Payment not found');
        if(p.signature)return respond(200,{state:'confirmed',signature:p.signature});
        if(p.submitted_signature)return respond(200,{state:'submitted',signature:p.submitted_signature});
        if(p.expires<=now())fail(409,'Payment review expired');
        let tx,transfer;
        try { tx=Transaction.from(Buffer.from(text(body.transaction,2200,true),'base64'));transfer=SystemInstruction.decodeTransfer(tx.instructions[0]); } catch { fail(400,'Invalid SOL transfer transaction'); }
        const instruction=tx.instructions[0];
        if(tx.instructions.length!==1 || tx.feePayer?.toBase58()!==me || transfer.fromPubkey.toBase58()!==me || transfer.toPubkey.toBase58()!==p.recipient || BigInt(transfer.lamports)!==BigInt(p.lamports) || instruction.keys.length!==3 || instruction.keys[2].pubkey.toBase58()!==p.reference || instruction.keys[2].isSigner || instruction.keys[2].isWritable || !tx.verifySignatures())fail(409,'Signed transaction does not match the reviewed payment');
        const signature=bs58.encode(tx.signature);
        // Persist before RPC I/O. An uncertain response must never invite re-signing.
        run('UPDATE payments SET submitted_signature=? WHERE id=?',signature,p.id);
        try { await rpc('sendTransaction',[body.transaction,{encoding:'base64',skipPreflight:false,preflightCommitment:'confirmed',maxRetries:2}]); }
        catch { return respond(202,{state:'uncertain',signature,message:'Submission outcome uncertain. Check this signature before retrying.'}); }
        return respond(202,{state:'submitted',signature});
      }
      if(route==='GET /api/payments')return respond(200,{payments:all('SELECT * FROM payments WHERE sender=? ORDER BY created DESC LIMIT 100',me)});
      if(route==='POST /api/payments/confirm') {
        const p=get('SELECT * FROM payments WHERE id=? AND sender=?',text(body.id,100,true),me);if(!p)fail(404,'Payment not found');
        if(p.signature)return respond(200,{state:'confirmed',signature:p.signature});
        const signature=text(body.signature || p.submitted_signature,100,true);let signatureBytes;try { signatureBytes=bs58.decode(signature); } catch { fail(400,'Invalid signature'); } if(signatureBytes.length!==64)fail(400,'Invalid signature');
        if(p.submitted_signature && p.submitted_signature!==signature)fail(409,'Check the original submitted signature');
        const tx=await rpc('getTransaction',[signature,{encoding:'jsonParsed',commitment:'confirmed',maxSupportedTransactionVersion:0}]);
        if(!tx)return respond(202,{state:'pending'});
        if(tx.meta?.err || !tx.meta)fail(409,'Transaction failed');
        const message=tx.transaction?.message;
        const keys=message?.accountKeys||[];
        const valid=keys.some(k=>k.pubkey===me&&k.signer)&&keys.some(k=>k.pubkey===p.reference)&&message.instructions.some(i=>i.programId==='11111111111111111111111111111111'&&i.parsed?.type==='transfer'&&i.parsed.info.source===me&&i.parsed.info.destination===p.recipient&&i.parsed.info.lamports===p.lamports);
        if(!valid)fail(409,'Transaction does not match the reviewed payment');
        if(get('SELECT 1 FROM payments WHERE signature=?',signature))fail(409,'Transaction already recorded');
        run('UPDATE payments SET signature=? WHERE id=?',signature,p.id);return respond(200,{state:'confirmed',signature});
      }
      if(route==='POST /rpc') {
        const allowed=['getLatestBlockhash','getBlockHeight','getSignatureStatuses','getBalance'];
        if(!allowed.includes(body.method)||!Array.isArray(body.params))fail(400,'Unsupported RPC method');
        const result=await rpc(body.method,body.params);return respond(200,{jsonrpc:'2.0',id:body.id??1,result});
      }
      if(route==='POST /api/media') {
        const kind=body.kind;if(!['avatar','video'].includes(kind))fail(400,'Invalid media kind');
        const encoded=text(body.base64,28*1024*1024,true);const bytes=Buffer.from(encoded,'base64');
        const limit=kind==='avatar'?2*1024*1024:20*1024*1024;
        if(!bytes.length||bytes.length>limit)fail(413,'Avatar limit is 2 MB; video limit is 20 MB');
        const png=bytes.subarray(0,8).equals(Buffer.from('89504e470d0a1a0a','hex'));
        const jpeg=bytes[0]===255&&bytes[1]===216&&bytes[2]===255;
        const mp4=bytes.length>16&&bytes.toString('ascii',4,8)==='ftyp'&&['isom','iso2','mp41','mp42','avc1','M4V '].includes(bytes.toString('ascii',8,12));
        if((kind==='avatar'&&!png&&!jpeg)||(kind==='video'&&!mp4))fail(400,'Use PNG/JPEG avatars or MP4 video');
        const mime=kind==='video'?'video/mp4':png?'image/png':'image/jpeg';const id=secret(16);
        const current=profile(me);delete current.wallet;delete current.updated;current[kind==='avatar'?'avatarMediaId':'videoMediaId']=id;
        db.exec('BEGIN IMMEDIATE');
        try { run('DELETE FROM media WHERE owner=? AND kind=?',me,kind);run('INSERT INTO media VALUES(?,?,?,?,?,?)',id,me,kind,mime,bytes,now());run('UPDATE profiles SET data=?,updated=? WHERE wallet=?',JSON.stringify(current),now(),me);db.exec('COMMIT'); } catch(error) {db.exec('ROLLBACK');throw error;}
        return respond(201,{id,profile:profile(me)});
      }
      if(req.method==='GET'&&path.startsWith('/api/media/')) {
        const media=get('SELECT * FROM media WHERE id=?',path.slice('/api/media/'.length));
        if(!media||!canRead(me,media.owner))fail(404,'Media unavailable');
        res.writeHead(200,{'Content-Type':media.mime,'Content-Length':media.bytes.length,'Content-Disposition':'inline'});res.end(Buffer.from(media.bytes));return;
      }
      if(route==='DELETE /api/media') {
        const kind=body.kind;if(!['avatar','video'].includes(kind))fail(400,'Invalid media kind');
        const current=profile(me);delete current.wallet;delete current.updated;current[kind==='avatar'?'avatarMediaId':'videoMediaId']=null;
        run('DELETE FROM media WHERE owner=? AND kind=?',me,kind);run('UPDATE profiles SET data=?,updated=? WHERE wallet=?',JSON.stringify(current),now(),me);return respond(200,{profile:profile(me)});
      }
      if(route==='GET /api/account/export')return respond(200,{profile:profile(me),connections:all('SELECT target,note,created FROM connections WHERE owner=?',me),events:all('SELECT event FROM members WHERE wallet=?',me),blocks:all('SELECT target FROM blocks WHERE owner=?',me),reports:all('SELECT target,reason,created,expires FROM reports WHERE owner=? AND expires>?',me,now()),payments:all('SELECT * FROM payments WHERE sender=?',me),media:all('SELECT id,kind,mime,bytes FROM media WHERE owner=?',me).map(m=>({...m,bytes:undefined,base64:Buffer.from(m.bytes).toString('base64')}))});
      if(route==='DELETE /api/account') {
        if(body.confirm!=='DELETE')fail(400,'Explicit deletion confirmation required');
        run('DELETE FROM challenges WHERE wallet=?',me);run('DELETE FROM profiles WHERE wallet=?',me);return respond(200,{ok:true});
      }
      fail(404,'Endpoint not found');
    } catch(error) {
      const status=error instanceof HttpError?error.status:(error.code==='ENOENT'?404:500);
      if(status===500)console.error('Aura request failed:',error.message);
      respond(status,{error:status===500?'Internal server error':error.message});
    }
  });
  server.on('close',()=>{clearInterval(interval);db.close();});
  return {server,db,sweep};
}
