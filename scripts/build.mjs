import {build} from 'esbuild';
import {mkdir,copyFile} from 'node:fs/promises';
await mkdir('dist',{recursive:true});
await build({entryPoints:['web/app.js'],bundle:true,format:'esm',outfile:'dist/app.js',target:'es2022',inject:['web/buffer-shim.js'],define:{'process.env.NODE_ENV':'"production"'}});
await Promise.all(['index.html','style.css'].map(f=>copyFile('web/'+f,'dist/'+f)));
console.log('Aura web companion built');
