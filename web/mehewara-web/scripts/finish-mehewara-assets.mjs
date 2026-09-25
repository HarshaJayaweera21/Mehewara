import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
const require = createRequire(import.meta.url);
// Usage: node scripts/finish-mehewara-assets.mjs <generated-image-directory> [sharp-module-path]
const sharp = require(process.argv[3] || 'sharp');
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const out = path.join(root,'public/assets/mehewara');
const manifest = JSON.parse(fs.readFileSync(path.join(out,'manifest.json'),'utf8'));
const sources = JSON.parse(fs.readFileSync(new URL('./mehewara-raster-sources.json',import.meta.url),'utf8'));
if(!process.argv[2]) throw new Error('Pass the directory containing the generated source PNGs.');
for(const {id,file,source} of sources){
  const a=manifest.assets.find(a=>a.id===id);
  await sharp(path.join(process.argv[2],source)).resize(a.width,a.height,{fit:'cover',position:'centre'}).webp({quality:86,effort:6}).toFile(path.join(out,file));
}
const verification=[];
for(const a of manifest.assets){
  const file=path.join(out,a.file);
  const metadata=await sharp(file).metadata();
  if(metadata.width!==a.width||metadata.height!==a.height)throw new Error('Wrong dimensions: '+a.file);
  const buffer=await sharp(file).ensureAlpha().resize({width:Math.min(a.width,640)}).raw().toBuffer({resolveWithObject:true});
  let transparent=0,visible=0;
  for(let i=3;i<buffer.data.length;i+=4){if(buffer.data[i]===0)transparent++;if(buffer.data[i]>0)visible++;}
  if(a.transparent&&!transparent)throw new Error('Missing transparency: '+a.file);
  if(!visible)throw new Error('Empty file: '+a.file);
  if(a.format==='svg'){
    const svg=fs.readFileSync(file,'utf8');
    if(/<script|<image|<foreignObject|https?:\/\/(?!www.w3.org)/.test(svg))throw new Error('Unexpected external/active content: '+a.file);
  }
  a.bytes=fs.statSync(file).size;
  verification.push({id:a.id,file:a.file,width:metadata.width,height:metadata.height,bytes:a.bytes,transparentPixels:transparent,passed:true});
}
if(manifest.assets.length!==62||new Set(manifest.assets.map(a=>a.id)).size!==62)throw new Error('Asset count mismatch');
fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
fs.writeFileSync(path.join(out,'verification.json'),JSON.stringify({assetCount:62,svgCount:52,webpCount:10,totalBytes:manifest.assets.reduce((n,a)=>n+a.bytes,0),checks:verification},null,2)+'\n');
console.log('Verified 62 assets: dimensions, decoding, nonempty content, SVG transparency and safe self-contained markup.');
console.log('Total asset bytes:',manifest.assets.reduce((n,a)=>n+a.bytes,0));
