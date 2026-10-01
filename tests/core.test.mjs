import {test} from 'node:test';
import assert from 'node:assert/strict';
import {lamports,profileInput,decode58} from '../server/core.mjs';
import {spatialVisibility} from '../packages/sdk/index.mjs';
test('SOL amounts use exact integer conversion and pilot limits',()=>{assert.equal(lamports('0.000000001'),1);assert.equal(lamports('1'),1e9);for(const v of ['0','-1','1.000000001','NaN','1e-3','0.0000000001',0.1])assert.throws(()=>lamports(v));});
test('profile input rejects unsafe links, invalid status, and unbounded text',()=>{const p={name:'Alice',role:'Builder',project:'Aura',bio:'',link:'https://example.com',video:'',intents:['Building'],status:'open'};assert.equal(profileInput(p).name,'Alice');for(const edit of [{link:'javascript:alert(1)'},{link:'https://user:pass@example.com'},{name:'x'.repeat(61)},{intents:['Unknown']},{status:'broadcast-all'}])assert.throws(()=>profileInput({...p,...edit}));});
test('spatial visibility requires a fresh measured transform',()=>{const v={worldTransform:Array(16).fill(0),measuredAt:10000,status:'active'};assert.equal(spatialVisibility(v,11000),true);for(const edit of [{worldTransform:null},{measuredAt:0},{measuredAt:12000},{status:'suspended'},{worldTransform:[NaN]}])assert.equal(spatialVisibility({...v,...edit},11000),false);});
test('base58 rejects invalid characters and preserves zero public key',()=>{assert.equal(decode58('1'.repeat(32)).length,32);assert.throws(()=>decode58('0IOl'));});
