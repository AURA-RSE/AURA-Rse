// Browser integration uses generated test wallets and an explicit mock devnet RPC.
// It proves UI/API/signing plumbing, not live wallet or blockchain execution.
import {chromium} from '@playwright/test';
import assert from 'node:assert/strict';
import {mkdir} from 'node:fs/promises';
import {createPrivateKey,sign,randomBytes} from 'node:crypto';
import {Keypair,Transaction} from '@solana/web3.js';
import bs58 from 'bs58';
import {createAura} from '../server/app.mjs';
import {AuraClient} from '../packages/sdk/index.mjs';
const origin='http://127.0.0.1:4321',alice=Keypair.generate(),bob=Keypair.generate();let submitted;
const {server}=createAura({dbPath:':memory:',origin,rpc:async(method,params)=>{
 if(method==='getLatestBlockhash')return {context:{slot:1},value:{blockhash:bs58.encode(randomBytes(32)),lastValidBlockHeight:1000}};
 if(method==='sendTransaction'){submitted=Transaction.from(Buffer.from(params[0],'base64'));return bs58.encode(submitted.signature);}
 if(method==='getTransaction'){if(!submitted)return null;const i=submitted.instructions[0];return {meta:{err:null},transaction:{message:{accountKeys:[{pubkey:alice.publicKey.toBase58(),signer:true},{pubkey:i.keys[2].pubkey.toBase58(),signer:false}],instructions:[{programId:'11111111111111111111111111111111',parsed:{type:'transfer',info:{source:alice.publicKey.toBase58(),destination:bob.publicKey.toBase58(),lamports:Number(i.data.readBigUInt64LE(4))}}}]}}};}
 throw new Error('Unexpected test RPC '+method);
}});
await new Promise(resolve=>server.listen(4321,'127.0.0.1',resolve));
let browser;
const signingKey=k=>createPrivateKey({key:Buffer.concat([Buffer.from('302e020100300506032b657004220420','hex'),Buffer.from(k.secretKey.subarray(0,32))]),format:'der',type:'pkcs8'});
try {
 browser=await chromium.launch({channel:'chrome',headless:true});const page=await browser.newPage({viewport:{width:1440,height:1050}});const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.exposeFunction('testSignMessage',message=>Array.from(sign(null,Buffer.from(message),signingKey(alice))));
 await page.exposeFunction('testSignTransaction',bytes=>{const tx=Transaction.from(Uint8Array.from(bytes));tx.partialSign(alice);return Array.from(tx.serialize());});
 await page.addInitScript(({address,publicKey})=>{
  const account={address,publicKey:Uint8Array.from(publicKey),chains:['solana:devnet'],features:['solana:signMessage','solana:signTransaction']};
  const wallet={name:'Aura Test Wallet',version:'1.0.0',icon:'data:image/svg+xml;base64,PHN2Zy8+',chains:['solana:devnet'],accounts:[account],features:{'standard:connect':{version:'1.0.0',connect:async()=>({accounts:[account]})},'standard:events':{version:'1.0.0',on:()=>()=>{}},'solana:signMessage':{version:'1.0.0',signMessage:async({message})=>[{signedMessage:message,signature:Uint8Array.from(await window.testSignMessage(Array.from(message)))}]},'solana:signTransaction':{version:'1.0.0',supportedTransactionVersions:['legacy'],signTransaction:async({transaction})=>[{signedTransaction:Uint8Array.from(await window.testSignTransaction(Array.from(transaction)))}]}}};
  window.addEventListener('wallet-standard:app-ready',event=>event.detail.register(wallet));
 },{address:alice.publicKey.toBase58(),publicKey:Array.from(alice.publicKey.toBytes())});
 await page.goto(origin);await page.locator('h1').waitFor();await mkdir('docs/evidence',{recursive:true});await page.screenshot({path:'docs/evidence/web-desktop.png',fullPage:true});
 await page.setViewportSize({width:390,height:844});assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);await page.screenshot({path:'docs/evidence/web-mobile.png',fullPage:true});await page.setViewportSize({width:1440,height:1050});
 await page.getByRole('button',{name:'Connect wallet ↗',exact:true}).click();await page.getByRole('button',{name:'Aura Test Wallet',exact:true}).click();await page.locator('#workspace').waitFor({state:'visible',timeout:5000}).catch(async e=>{console.error('Sign-in notice:',await page.locator('#notice').textContent());console.error('Browser errors:',errors);throw e;});
 await page.locator('[name="name"]').first().fill('Alice Test');await page.locator('[name="role"]').fill('Builder');await page.locator('[name="project"]').fill('Aura');await page.locator('[name="status"]').selectOption('open');await page.getByRole('button',{name:'Save profile ↗'}).click();await page.getByText('Profile saved. Your presence setting is enforced by the server.').waitFor();
 await page.locator('#event [name=code]').fill('AURA-LAB');await page.getByRole('button',{name:'Join event',exact:true}).click();await page.getByText('Joined Aura Local Lab. Select it in the Aura mobile app to start discovery.').waitFor();
 const a=new AuraClient({baseURL:origin}),b=new AuraClient({baseURL:origin});await a.signIn(alice.publicKey.toBase58(),m=>sign(null,Buffer.from(m),signingKey(alice)));await b.signIn(bob.publicKey.toBase58(),m=>sign(null,Buffer.from(m),signingKey(bob)));await b.saveProfile({name:'Bob Test',role:'Designer',project:'Test fixture',bio:'Synthetic browser-test participant',link:'',video:'',status:'open',intents:['Looking for a team']});await b.join('AURA-LAB');const presence=await b.advertise('aura-lab');await a.resolve(presence.token);await a.saveConnection(bob.publicKey.toBase58(),'Private test note');await page.locator('#refresh').click();await page.getByText('Bob Test',{exact:true}).waitFor();
 page.once('dialog',dialog=>dialog.accept('0.01'));await page.getByRole('button',{name:'Send devnet SOL',exact:true}).click();await page.locator('#payment-dialog').waitFor({state:'visible'});await page.getByRole('button',{name:'Continue to wallet ↗'}).click();await page.getByText('Confirmed on Solana devnet.',{exact:true}).waitFor();assert.ok(submitted);assert.equal((await a.request('/api/payments')).payments[0].signature,bs58.encode(submitted.signature));
 await page.locator('#avatar-upload').setInputFiles({name:'avatar.png',mimeType:'image/png',buffer:Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aNXYAAAAASUVORK5CYII=','base64')});await page.getByText('Media saved with your Aura profile.',{exact:true}).waitFor();await page.locator('#my-media img').waitFor();
 await page.screenshot({path:'docs/evidence/web-workspace-test-fixtures.png',fullPage:true});assert.deepEqual(errors,[]);
 console.log('PASS: desktop/mobile layout, wallet challenge, profile save, event join, saved connection, reviewed signed payment, verified receipt, durable avatar upload. RPC and wallets were test fixtures.');
}finally{await browser?.close();await new Promise(resolve=>server.close(resolve));}
