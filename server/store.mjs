import { DatabaseSync } from 'node:sqlite';
import { mkdirSync, chmodSync } from 'node:fs';
import { dirname } from 'node:path';
export const REPORT_RETENTION_MS = 90 * 86400000;
export const SCHEMA_VERSION = 3;

export function openStore(path) {
  if (path !== ':memory:') mkdirSync(dirname(path), { recursive:true, mode:0o700 });
  const db = new DatabaseSync(path);
  if (path !== ':memory:') chmodSync(path, 0o600);
  db.exec(`PRAGMA foreign_keys=ON; PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000;
  CREATE TABLE IF NOT EXISTS schema_version(version INTEGER PRIMARY KEY);
  INSERT OR IGNORE INTO schema_version VALUES(1);
  CREATE TABLE IF NOT EXISTS profiles(wallet TEXT PRIMARY KEY, data TEXT NOT NULL, updated INTEGER NOT NULL);
  CREATE TABLE IF NOT EXISTS challenges(id TEXT PRIMARY KEY, wallet TEXT NOT NULL, message TEXT NOT NULL, expires INTEGER NOT NULL);
  CREATE TABLE IF NOT EXISTS sessions(hash TEXT PRIMARY KEY, wallet TEXT NOT NULL REFERENCES profiles(wallet) ON DELETE CASCADE, expires INTEGER NOT NULL);
  CREATE TABLE IF NOT EXISTS events(id TEXT PRIMARY KEY, owner TEXT REFERENCES profiles(wallet) ON DELETE CASCADE, name TEXT NOT NULL, code TEXT UNIQUE NOT NULL, created INTEGER NOT NULL);
  CREATE TABLE IF NOT EXISTS members(event TEXT REFERENCES events(id) ON DELETE CASCADE, wallet TEXT REFERENCES profiles(wallet) ON DELETE CASCADE, PRIMARY KEY(event,wallet));
  CREATE TABLE IF NOT EXISTS presence(hash TEXT PRIMARY KEY, wallet TEXT UNIQUE NOT NULL REFERENCES profiles(wallet) ON DELETE CASCADE, event TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE, expires INTEGER NOT NULL);
  CREATE TABLE IF NOT EXISTS access(viewer TEXT REFERENCES profiles(wallet) ON DELETE CASCADE, target TEXT REFERENCES profiles(wallet) ON DELETE CASCADE, expires INTEGER NOT NULL, PRIMARY KEY(viewer,target));
  CREATE TABLE IF NOT EXISTS connections(owner TEXT REFERENCES profiles(wallet) ON DELETE CASCADE, target TEXT REFERENCES profiles(wallet) ON DELETE CASCADE, note TEXT NOT NULL, created INTEGER NOT NULL, PRIMARY KEY(owner,target));
  CREATE TABLE IF NOT EXISTS blocks(owner TEXT REFERENCES profiles(wallet) ON DELETE CASCADE, target TEXT REFERENCES profiles(wallet) ON DELETE CASCADE, PRIMARY KEY(owner,target));
  CREATE TABLE IF NOT EXISTS reports(id TEXT PRIMARY KEY, owner TEXT REFERENCES profiles(wallet) ON DELETE CASCADE, target TEXT REFERENCES profiles(wallet) ON DELETE CASCADE, reason TEXT NOT NULL, created INTEGER NOT NULL);
  CREATE TABLE IF NOT EXISTS devices(hash TEXT PRIMARY KEY, code TEXT UNIQUE NOT NULL, wallet TEXT REFERENCES profiles(wallet) ON DELETE CASCADE, expires INTEGER NOT NULL);
  CREATE TABLE IF NOT EXISTS ranging(id TEXT PRIMARY KEY, sender TEXT REFERENCES profiles(wallet) ON DELETE CASCADE, recipient TEXT REFERENCES profiles(wallet) ON DELETE CASCADE, sender_token TEXT NOT NULL, recipient_token TEXT, expires INTEGER NOT NULL);
  CREATE TABLE IF NOT EXISTS payments(id TEXT PRIMARY KEY, sender TEXT REFERENCES profiles(wallet) ON DELETE CASCADE, recipient TEXT NOT NULL, lamports INTEGER NOT NULL, reference TEXT NOT NULL, signature TEXT UNIQUE, expires INTEGER NOT NULL, created INTEGER NOT NULL);
  CREATE TABLE IF NOT EXISTS media(id TEXT PRIMARY KEY, owner TEXT NOT NULL REFERENCES profiles(wallet) ON DELETE CASCADE, kind TEXT NOT NULL, mime TEXT NOT NULL, bytes BLOB NOT NULL, created INTEGER NOT NULL, UNIQUE(owner,kind));
  CREATE INDEX IF NOT EXISTS presence_event ON presence(event,expires);
  CREATE INDEX IF NOT EXISTS ranging_recipient ON ranging(recipient,expires);
  `);
  const version = db.prepare('SELECT MAX(version) AS v FROM schema_version').get().v;
  if (version > SCHEMA_VERSION) { db.close(); throw new Error('Unsupported database schema'); }
  if (version < 2) {
    db.exec('BEGIN IMMEDIATE; ALTER TABLE payments ADD COLUMN submitted_signature TEXT; INSERT INTO schema_version VALUES(2); COMMIT;');
  }
  if (version < 3) {
    // Preserve abuse reports independently of the reported account. Deleting the
    // reporter clears their account link; the original expiry never resets.
    try {
      db.exec(`BEGIN IMMEDIATE;
        CREATE TABLE reports_v3(
          id TEXT PRIMARY KEY,
          owner TEXT REFERENCES profiles(wallet) ON DELETE SET NULL,
          target TEXT NOT NULL,
          reason TEXT NOT NULL,
          created INTEGER NOT NULL,
          expires INTEGER NOT NULL
        );`);
      db.prepare(`INSERT INTO reports_v3(id,owner,target,reason,created,expires)
        SELECT id,owner,target,reason,created,created+? FROM reports`).run(REPORT_RETENTION_MS);
      db.exec(`DROP TABLE reports;
        ALTER TABLE reports_v3 RENAME TO reports;
        CREATE INDEX reports_expiry ON reports(expires);
        INSERT INTO schema_version VALUES(3);
        COMMIT;`);
    } catch (error) {
      try { db.exec('ROLLBACK'); } catch { /* BEGIN may itself have failed. */ }
      db.close();
      throw error;
    }
  }
  return db;
}
