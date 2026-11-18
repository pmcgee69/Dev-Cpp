// Runs ParseCorpus.wasm on upstream's parser corpus and compares each file's statements with
// delfcpp-tests' golden files (recorded from upstream master, built by dcc for Win32).
//   node run-corpus.mjs <ParseCorpus.wasm> <Source\Tests\Parser> <delfcpp-tests\golden>
import { readFile } from 'node:fs/promises';
import { WASI } from 'node:wasi';
import { existsSync } from 'node:fs';
import { join } from 'node:path';

const [wasmPath, corpus, golden] = process.argv.slice(2);
const files = ['Code.cpp', 'Function.cpp', 'Include.cpp', 'OperatorTest.cpp', 'Preprocessor.cpp',
  'SimpleClass.cpp', 'Struct.cpp', 'Typedef.cpp', 'Variable.cpp', 'float3.cpp', 'string.cpp',
  'stl/basic_string.h', 'stl/stl_deque.h', 'stl/stl_list.h', 'stl/stl_map.h', 'stl/stl_queue.h',
  'stl/stl_stack.h', 'stl/stl_vector.h'];
const mod = await WebAssembly.compile(await readFile(wasmPath));

// One run a file: stdout captured through a WASI file descriptor of our own
async function parse(file) {
  const { openSync, readFileSync, closeSync, mkdtempSync } = await import('node:fs');
  const { tmpdir } = await import('node:os');
  const out = join(mkdtempSync(join(tmpdir(), 'pc-')), 'out.txt');
  const fd = openSync(out, 'w');
  const wasi = new WASI({ version: 'preview1', args: ['ParseCorpus', '/corpus/' + file],
    preopens: { '/corpus': corpus }, stdout: fd, returnOnExit: true });
  const inst = await WebAssembly.instantiate(mod, wasi.getImportObject());
  const code = wasi.start(inst);
  closeSync(fd);
  return { code, text: readFileSync(out, 'utf8') };
}

let same = 0, differ = 0;
for (const f of files) {
  const { code, text } = await parse(f);
  const got = text.split(/\r?\n/).filter(l => l && !l.startsWith('== ')).join('\n');
  const gf = join(golden, f.replace('/', '_').replace(/\.(cpp|h)$/, '.txt'));
  const want = existsSync(gf) ? (await readFile(gf, 'utf8')).replace(/^﻿/, '').split(/\r?\n/).filter(l => l).join('\n') : null;
  if (code === 0 && got === want) { same++; console.log('same     ', f); }
  else {
    differ++;
    const g = got.split('\n'), w = (want ?? '').split('\n');
    let i = 0; while (i < g.length && g[i] === w[i]) i++;
    console.log('DIFFERS  ', f, `(exit ${code}; ${g.length} statements, golden ${w.length}; first difference at ${i + 1})`);
    console.log('   wasm:  ', g[i] ?? '(none)');
    console.log('   golden:', w[i] ?? '(none)');
  }
}
console.log(`${same} files the same as the Win32 golden files, ${differ} differ`);
process.exitCode = differ ? 1 : 0;
