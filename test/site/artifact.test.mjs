import assert from 'node:assert/strict';
import { cp, mkdtemp, readFile, readdir, rm, symlink, unlink, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { pathToFileURL } from 'node:url';
import { buildPages, publicFiles } from '../../tool/build_pages.mjs';

test('deployment copies only the public allowlist, excluding stray keys and files', async (context) => {
  const root = await mkdtemp(join(tmpdir(), 'tunnio-pages-'));
  context.after(() => rm(root, { recursive: true, force: true }));
  const source = pathToFileURL(join(root, 'source') + '/');
  const destination = pathToFileURL(join(root, 'output') + '/');
  await cp(new URL('../../site/encrypt/', import.meta.url), source, { recursive: true });
  await writeFile(new URL('private.pem', source), 'TEST PRIVATE KEY MUST NOT BE PUBLISHED');
  await writeFile(new URL('env.local.json', source), '{"test":"do not publish"}');
  await buildPages(source, destination);
  assert.deepEqual((await readdir(destination)).sort(), [...publicFiles].sort());
  for (const file of publicFiles) {
    assert.deepEqual(await readFile(new URL(file, destination)), await readFile(new URL(file, source)));
  }
  await unlink(new URL('public.pem', source));
  await symlink(new URL('private.pem', source), new URL('public.pem', source));
  await assert.rejects(buildPages(source, destination), /regular public file/);
});

test('page blocks submissions and loads only local scripts and styles', async () => {
  const html = await readFile(new URL('../../site/encrypt/index.html', import.meta.url), 'utf8');
  assert.match(html, /form-action 'none'/);
  assert.match(html, /default-src 'none'/);
  assert.match(html, /script-src 'self'/);
  assert.doesNotMatch(html, /unsafe-inline|unsafe-eval|\son[a-z]+=/i);
  for (const match of html.matchAll(/(?:src|href)="([^"]+)"/g)) {
    assert.ok(match[1].startsWith('./') || match[1] === 'https://github.com/phungvanquy/Tunnio');
  }
  assert.match(html, /id="encrypt"[^>]*disabled/);
  assert.doesNotMatch(html, /<(?:input|textarea)[^>]*\bname=/);
});
