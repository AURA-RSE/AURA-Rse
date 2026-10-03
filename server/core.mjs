import { createHash, randomBytes, createPublicKey, verify } from 'node:crypto';
export class HttpError extends Error { constructor(status, message) { super(message); this.status = status; } }
export const fail = (status, message) => { throw new HttpError(status, message); };
export const secret = (bytes = 32) => randomBytes(bytes).toString('base64url');
export const hash = value => createHash('sha256').update(value).digest('hex');
const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
export function decode58(value) {
  if (typeof value !== 'string' || value.length > 100) fail(400, 'Invalid base58 value');
  let n = 0n;
  for (const c of value) { const i = alphabet.indexOf(c); if (i < 0) fail(400, 'Invalid base58 value'); n = n * 58n + BigInt(i); }
  const bytes = []; while (n) { bytes.unshift(Number(n % 256n)); n /= 256n; }
  for (const c of value) { if (c !== '1') break; bytes.unshift(0); }
  return Buffer.from(bytes);
}
export function wallet(value) { if (decode58(value).length !== 32) fail(400, 'Invalid Solana wallet'); return value; }
export function text(value, max, required = false) {
  if (typeof value !== 'string' || value.length > max || (required && !value.trim())) fail(400, `Expected text up to ${max} characters`);
  return value.trim();
}
export function httpsURL(value) {
  if (!value) return '';
  text(value, 500); let url; try { url = new URL(value); } catch { fail(400, 'Invalid URL'); }
  if (url.protocol !== 'https:' || url.username || url.password) fail(400, 'Links must use HTTPS without credentials');
  return url.href;
}
export function verifyWallet(address, message, signature) {
  const bytes = Buffer.from(typeof signature === 'string' ? signature : '', 'base64');
  if (bytes.length !== 64) return false;
  const key = createPublicKey({key: Buffer.concat([Buffer.from('302a300506032b6570032100', 'hex'), decode58(address)]), format:'der', type:'spki'});
  return verify(null, Buffer.from(message), key, bytes);
}
export function lamports(value) {
  if (typeof value !== 'string' || !/^(0|[1-9]\d{0,2})(\.\d{1,9})?$/.test(value)) fail(400, 'Enter a SOL amount with at most nine decimal places');
  const [whole, fraction = ''] = value.split('.'); const n = BigInt(whole) * 1000000000n + BigInt(fraction.padEnd(9, '0'));
  if (n <= 0n || n > 1000000000n) fail(400, 'Pilot payments must be greater than zero and at most 1 devnet SOL');
  return Number(n);
}
export function profileInput(body) {
  const statuses = ['open', 'heads-down', 'stealth'];
  const intents = ['Building', 'Hiring', 'Fundraising', 'Looking for a team', 'Offering feedback', 'Open to connect'];
  if (!statuses.includes(body.status)) fail(400, 'Invalid presence status');
  if (!Array.isArray(body.intents) || body.intents.length > 6 || body.intents.some(i => !intents.includes(i))) fail(400, 'Invalid intents');
  if (body.eventDirectory !== undefined && typeof body.eventDirectory !== 'boolean') fail(400, 'Invalid event directory setting');
  return {eventDirectory:body.eventDirectory === true, name:text(body.name,60,true), role:text(body.role,80), project:text(body.project,100), bio:text(body.bio,500),
    link:httpsURL(body.link), video:httpsURL(body.video), intents:[...new Set(body.intents)], status:body.status};
}
