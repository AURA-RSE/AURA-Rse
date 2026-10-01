import {test} from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {mkdtemp,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {openStore,REPORT_RETENTION_MS,SCHEMA_VERSION} from '../server/store.mjs';
import {createAura} from '../server/app.mjs';

for (const version of [1,2]) test(`schema v${version} migration preserves reports and original retention deadlines across reopen`,async t => {
 const dir=await mkdtemp(join(tmpdir(),'aura-migration-'));
 t.after(()=>rm(dir,{recursive:true,force:true}));
 const path=join(dir,'legacy.sqlite'),now=Date.now();
 const legacy=new DatabaseSync(path);
 legacy.exec(`PRAGMA foreign_keys=ON;
  CREATE TABLE schema_version(version INTEGER PRIMARY KEY);
  INSERT INTO schema_version VALUES(${version});
  CREATE TABLE profiles(wallet TEXT PRIMARY KEY,data TEXT NOT NULL,updated INTEGER NOT NULL);
  CREATE TABLE reports(id TEXT PRIMARY KEY,owner TEXT REFERENCES profiles(wallet) ON DELETE CASCADE,target TEXT REFERENCES profiles(wallet) ON DELETE CASCADE,reason TEXT NOT NULL,created INTEGER NOT NULL);
  CREATE TABLE payments(id TEXT PRIMARY KEY,sender TEXT REFERENCES profiles(wallet) ON DELETE CASCADE,recipient TEXT NOT NULL,lamports INTEGER NOT NULL,reference TEXT NOT NULL,signature TEXT UNIQUE,expires INTEGER NOT NULL,created INTEGER NOT NULL${version===2?',submitted_signature TEXT':''});`);
 for(const wallet of ['reporter','target'])legacy.prepare('INSERT INTO profiles VALUES(?,?,?)').run(wallet,'{}',now);
 legacy.prepare('INSERT INTO reports VALUES(?,?,?,?,?)').run('recent','reporter','target','Keep for review',now-1000);
 legacy.prepare('INSERT INTO reports VALUES(?,?,?,?,?)').run('expired','reporter','target','Remove on startup',now-REPORT_RETENTION_MS);
 legacy.prepare('INSERT INTO payments(id,sender,recipient,lamports,reference,signature,expires,created) VALUES(?,?,?,?,?,?,?,?)').run('payment','reporter','target',1,'ref','confirmed-fixture',now+1000,now);
 legacy.close();
 const app=createAura({dbPath:path,clock:()=>now});
 try {
  assert.equal(app.db.prepare('SELECT MAX(version) AS v FROM schema_version').get().v,SCHEMA_VERSION);
  assert.equal(app.db.prepare('SELECT COUNT(*) AS n FROM reports').get().n,1);
  const report=app.db.prepare('SELECT * FROM reports').get();
  assert.equal(report.id,'recent');assert.equal(report.expires,now-1000+REPORT_RETENTION_MS);
  assert.equal(app.db.prepare('SELECT signature FROM payments').get().signature,'confirmed-fixture');
  app.db.prepare('DELETE FROM profiles WHERE wallet=?').run('target');
  assert.equal(app.db.prepare('SELECT reason FROM reports').get().reason,'Keep for review');
  assert.deepEqual(app.db.prepare('PRAGMA foreign_key_check').all(),[]);
 } finally { app.server.emit('close'); }
 const reopened=createAura({dbPath:path,clock:()=>now+REPORT_RETENTION_MS-1000});
 try { assert.equal(reopened.db.prepare('SELECT COUNT(*) AS n FROM reports').get().n,0); }
 finally { reopened.server.emit('close'); }
});

test('store rejects an unknown future schema',async t => {
 const dir=await mkdtemp(join(tmpdir(),'aura-future-schema-'));
 t.after(()=>rm(dir,{recursive:true,force:true}));
 const path=join(dir,'future.sqlite'),db=openStore(path);
 db.prepare('INSERT INTO schema_version VALUES(?)').run(SCHEMA_VERSION+1);db.close();
 assert.throws(()=>openStore(path),/Unsupported database schema/);
});
