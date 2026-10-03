import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { matchesGlob } from 'node:path';
import { test } from 'node:test';

const build = await readFile(new URL('../../.github/workflows/build.yaml', import.meta.url), 'utf8');
const pages = await readFile(new URL('../../.github/workflows/pages.yaml', import.meta.url), 'utf8');

function eventBlock(workflow, event) {
  const block = workflow.match(new RegExp(`^  ${event}:\\n((?:    .*\\n|\\n)+)`, 'm'))?.[1];
  assert.ok(block, `Missing ${event} event`);
  return block;
}

function paths(block, key) {
  const list = block.match(new RegExp(`^    ${key}:\\n((?:      - '[^']+'\\n)+)`, 'm'))?.[1];
  assert.ok(list, `Missing ${key} list`);
  return [...list.matchAll(/- '([^']+)'/g)].map((match) => match[1]);
}

const ignored = paths(eventBlock(build, 'push'), 'paths-ignore');
const pagePush = paths(eventBlock(pages, 'push'), 'paths');
const pagePullRequest = paths(eventBlock(pages, 'pull_request'), 'paths');
const matches = (file, patterns) => patterns.some((pattern) => matchesGlob(file, pattern));

test('page-only changes skip app packaging and trigger page verification', () => {
  assert.deepEqual(ignored, ['site/**', 'test/site/**', 'tool/build_pages.mjs', '.github/workflows/pages.yaml']);
  for (const file of [
    'site/encrypt/index.html', 'site/encrypt/vendor/incy/web.mjs', 'site/README.md',
    'test/site/workflow.test.mjs', 'tool/build_pages.mjs', '.github/workflows/pages.yaml',
  ]) {
    assert.equal(matches(file, ignored), true, file);
    assert.equal(matches(file, pagePush), true, file);
    assert.equal(matches(file, pagePullRequest), true, file);
  }
});

test('app and mixed changes retain app builds; build filter edits also verify Pages', () => {
  for (const file of ['lib/main.dart', 'pubspec.yaml', 'core/main.go', 'android/app/build.gradle.kts',
    'test/build_workflow_test.dart', '.github/workflows/build.yaml']) {
    assert.equal(matches(file, ignored), false, file);
    const mixed = ['site/encrypt/app.mjs', file];
    assert.equal(mixed.every((changed) => matches(changed, ignored)), false);
  }
  assert.equal(matches('.github/workflows/build.yaml', pagePush), true);
  assert.equal(matches('.github/workflows/build.yaml', pagePullRequest), true);
});

test('release tags and manual app builds remain enabled independently of page paths', () => {
  assert.match(eventBlock(build, 'push'), /    tags:\n      - 'v\*'/);
  assert.match(eventBlock(build, 'push'), /    branches:\n      - '\*\*'/);
  assert.match(build, /^  workflow_dispatch:/m);
  assert.match(build, /if: github.event_name == 'workflow_dispatch' \|\| github.event_name == 'push'/);
});

test('Pages publishes only main after verification and requires no app tooling or secrets', () => {
  assert.match(pages, /run: node --test test\/site\/\*\.test\.mjs/);
  assert.match(pages, /run: node tool\/build_pages\.mjs/);
  assert.match(pages, /path: build\/pages/);
  assert.match(pages, /deploy:\n    if: github.ref == 'refs\/heads\/main' && github.event_name != 'pull_request'\n    needs: verify/);
  assert.match(pages, /name: Upload Pages artifact\n        if: github.ref == 'refs\/heads\/main' && github.event_name != 'pull_request'/);
  assert.doesNotMatch(pages, /secrets\.|flutter|setup-java|setup-go|submodules:/);
});
