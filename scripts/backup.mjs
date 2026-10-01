import {DatabaseSync} from 'node:sqlite';
import {resolve,dirname} from 'node:path';
import {mkdirSync,chmodSync,existsSync} from 'node:fs';
const source=resolve(process.env.AURA_DB||'data/aura.sqlite');
if(!existsSync(source))throw new Error("Source database does not exist");
const destination=process.argv[2];
if(!destination)throw new Error('Usage: node scripts/backup.mjs /absolute/path/to/new-backup.sqlite');
const target=resolve(destination);if(target===source)throw new Error('Backup must be a different path');
mkdirSync(dirname(target),{recursive:true,mode:0o700});
const db=new DatabaseSync(source);try { db.prepare('VACUUM INTO ?').run(target);chmodSync(target,0o600);console.log('Consistent SQLite snapshot created:',target); } finally { db.close(); }
