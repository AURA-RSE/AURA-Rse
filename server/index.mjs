import { createAura } from './app.mjs';
const port=Number(process.env.PORT||4317);
const origin=process.env.AURA_ORIGIN||`http://localhost:${port}`;
const {server}=createAura({dbPath:process.env.AURA_DB||'data/aura.sqlite',origin});
server.listen(port,process.env.HOST||'127.0.0.1',()=>console.log(`Aura pilot: ${origin} (devnet only)`));
for(const signal of ['SIGINT','SIGTERM'])process.on(signal,()=>server.close(()=>process.exit(0)));
