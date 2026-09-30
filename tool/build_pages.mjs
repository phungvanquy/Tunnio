import { copyFile, lstat, mkdir, readFile, rm } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import { importPublicKey } from '../site/encrypt/crypto.mjs';

export const publicFiles = [
  'index.html', 'app.mjs', 'crypto.mjs', 'style.css', 'public.pem', 'icon.png',
  'qr.mjs', 'vendor/qrcode.mjs', 'vendor/qrcode.LICENSE.txt',
];

export async function buildPages(
  source = new URL('../site/encrypt/', import.meta.url),
  destination = new URL('../build/pages/', import.meta.url),
) {
  for (const file of publicFiles) {
    if (!(await lstat(new URL(file, source))).isFile()) {
      throw new Error(`Expected a regular public file: ${file}`);
    }
  }
  const key = await importPublicKey(await readFile(new URL('public.pem', source), 'utf8'));
  await rm(destination, { recursive: true, force: true });
  await mkdir(destination, { recursive: true });
  for (const file of publicFiles) {
    await mkdir(new URL('.', new URL(file, destination)), { recursive: true });
    await copyFile(new URL(file, source), new URL(file, destination));
  }
  return key;
}

if (process.argv[1] && pathToFileURL(process.argv[1]).href === import.meta.url) {
  const { fingerprint } = await buildPages();
  console.log(`Prepared ${publicFiles.length} public files. Public key SHA-256: ${fingerprint}`);
}
