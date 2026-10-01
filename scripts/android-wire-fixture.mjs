// Public, unfunded fixture generated with Solana's SDK to check the independent Android decoder.
import {Keypair,Transaction,SystemProgram,PublicKey} from '@solana/web3.js';
import {writeFileSync} from 'node:fs';
const sender=Keypair.fromSeed(new Uint8Array(32).fill(1)),recipient=Keypair.fromSeed(new Uint8Array(32).fill(2)).publicKey,reference=Keypair.fromSeed(new Uint8Array(32).fill(3)).publicKey;
const tx=new Transaction({feePayer:sender.publicKey,recentBlockhash:new PublicKey(new Uint8Array(32).fill(4)).toBase58()});
const ix=SystemProgram.transfer({fromPubkey:sender.publicKey,toPubkey:recipient,lamports:123456789});ix.keys.push({pubkey:reference,isSigner:false,isWritable:false});tx.add(ix);
const unsigned=tx.serialize({requireAllSignatures:false,verifySignatures:false}).toString('base64');tx.sign(sender);
writeFileSync(process.argv[2],Object.entries({sender:sender.publicKey.toBase58(),recipient:recipient.toBase58(),reference:reference.toBase58(),lamports:123456789,unsigned,signed:tx.serialize().toString('base64')}).map(([k,v])=>`${k}=${v}`).join('\n'));
