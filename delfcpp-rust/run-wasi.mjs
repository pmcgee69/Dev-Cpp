// node run-wasi.mjs <tokdump.wasm> <root> <outdir> <name>: runs the WASI build over <outdir>/<name>.list
// with <root> mapped as /root and <outdir> as /out; writes <outdir>/<name>.wasm.txt.
import { readFile } from 'node:fs/promises';
import { WASI } from 'node:wasi';

const [wasmPath, root, outDir, name] = process.argv.slice(2);
const wasi = new WASI({
  version: 'preview1',
  args: ['tokdump', '/root', `/out/${name}.list`, `/out/${name}.wasm.txt`],
  preopens: { '/root': root, '/out': outDir },
});
const module = await WebAssembly.compile(await readFile(wasmPath));
const instance = await WebAssembly.instantiate(module, wasi.getImportObject());
process.exitCode = wasi.start(instance);
