// Runs only against the Aura-owned emulator. Wallet/API accounts are generated test fixtures.
import {createAura} from '../server/app.mjs';
import {AuraClient} from '../packages/sdk/index.mjs';
import {generateKeyPairSync,sign} from 'node:crypto';
import {spawn} from 'node:child_process';
import {mkdirSync,writeFileSync} from 'node:fs';
import bs58 from 'bs58';
const adb=process.env.AURA_ADB||'.toolchains/android-sdk/platform-tools/adb';
const serial=process.env.AURA_EMULATOR_SERIAL||'emulator-5580';
if(!/^emulator-\d+$/.test(serial))throw Error('This fixture runner only targets an emulator.');
const command=(args)=>new Promise((resolve,reject)=>{const p=spawn(adb,['-s',serial,...args],{stdio:['ignore','pipe','pipe']});let output='';p.stdout.on('data',d=>output+=d);p.stderr.on('data',d=>output+=d);p.on('error',reject);p.on('exit',code=>code?reject(Error(output)):resolve(output));});
if(!(await command(['emu','avd','name'])).includes('Aura_Pilot_API35'))throw Error('Refusing to run fixtures on an unrelated emulator.');
const {server}=createAura({dbPath:':memory:',origin:'http://10.0.2.2:4322',rpc:async()=>{throw Error('Live RPC disabled in Android UI test');}});
await new Promise(resolve=>server.listen(4322,'127.0.0.1',resolve));
try{
 const key=generateKeyPairSync('ed25519'),wallet=bs58.encode(key.publicKey.export({format:'der',type:'spki'}).subarray(-32));
 const client=new AuraClient({baseURL:'http://127.0.0.1:4322'});await client.signIn(wallet,m=>sign(null,Buffer.from(m),key.privateKey));
 await client.saveProfile({name:'Android fixture',role:'Builder',project:'Aura test fixture',bio:'Generated UI test account',link:'',video:'',status:'open',intents:['Building']});await client.join('AURA-LAB');
 await command(['install','-r','android/app/build/outputs/apk/debug/app-debug.apk']);await command(['install','-r','android/app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk']);
 const output=await command(['shell','am','instrument','-w','-r','-e','auraOrigin','http://10.0.2.2:4322','-e','auraToken',client.token,'app.aura.pilot.test/androidx.test.runner.AndroidJUnitRunner']);
 mkdirSync('docs/evidence',{recursive:true});writeFileSync('docs/evidence/android-device-tests.txt',output);console.log(output);
 if(!/OK \(3 tests\)/.test(output))throw Error('Android instrumentation did not pass all 3 tests');
 await command(['shell','am','start','-n','app.aura.pilot/.MainActivity']);
 console.log('PASS: isolated emulator UI / Keystore / API tests. No real wallet or radio proof claimed.');
}finally{await new Promise(resolve=>server.close(resolve));}
