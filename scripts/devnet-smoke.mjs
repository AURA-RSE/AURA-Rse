// Optional real-network check. Uses NEW in-memory test keys and DEVNET only.
// Never reads a user wallet, keypair file, or mainnet RPC endpoint.
import {Connection,Keypair,SystemProgram,Transaction} from '@solana/web3.js';
import {writeFile,mkdir} from 'node:fs/promises';
if(process.env.AURA_ALLOW_DEVNET_SMOKE!=='1')throw new Error('Set AURA_ALLOW_DEVNET_SMOKE=1 to request test devnet SOL and send one test transfer.');
const connection=new Connection('https://api.devnet.solana.com',{commitment:'confirmed',disableRetryOnRateLimit:true,fetch:(url,options)=>fetch(url,{...options,signal:AbortSignal.timeout(15000)})});
const sender=Keypair.generate(),recipient=Keypair.generate();
const evidence={date:new Date().toISOString(),network:'devnet',test:'generated-wallet SOL transfer',status:'not_completed'};
await mkdir('docs/evidence',{recursive:true});
try{
 const airdrop=await connection.requestAirdrop(sender.publicKey,20000000);evidence.airdrop=airdrop;
 for(let i=0;i<15;i++){if(await connection.getBalance(sender.publicKey)>=2000000)break;await new Promise(r=>setTimeout(r,1500));}
 if(await connection.getBalance(sender.publicKey)<2000000)throw new Error('Devnet faucet did not fund the test wallet in time');
 const latest=await connection.getLatestBlockhash();const tx=new Transaction({...latest,feePayer:sender.publicKey}).add(SystemProgram.transfer({fromPubkey:sender.publicKey,toPubkey:recipient.publicKey,lamports:1000000}));tx.sign(sender);
 const signature=await connection.sendRawTransaction(tx.serialize(),{skipPreflight:false,maxRetries:2});evidence.signature=signature;
 for(let i=0;i<15;i++){const receipt=await connection.getTransaction(signature,{commitment:'confirmed',maxSupportedTransactionVersion:0});if(receipt?.meta&&receipt.meta.err===null){evidence.status='confirmed';evidence.slot=receipt.slot;break;}await new Promise(r=>setTimeout(r,1500));}
 if(evidence.status!=='confirmed')throw new Error('Confirmation unresolved; check the recorded signature before retrying');
}catch(error){evidence.reason=error.message;console.error(error.message);process.exitCode=1;}
await writeFile('docs/evidence/devnet-smoke.json',JSON.stringify(evidence,null,2)+'\n');
console.log(JSON.stringify(evidence));
