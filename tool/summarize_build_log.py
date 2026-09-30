import base64
import os
from pathlib import Path
import re
import sys


def summarize_build_log(log, private_key='', max_lines=60):
    secrets = {private_key, ''.join(private_key.split())} - {''}
    for value in tuple(secrets):
        secrets.add(base64.b64encode(
            f'VPN_RSA_PRIVATE_KEY_B64={value}'.encode(),
        ).decode())
    for value in sorted(secrets, key=len, reverse=True):
        log = log.replace(value, '[REDACTED]')
    log = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', log)
    lines = log.splitlines()
    error = re.compile(
        r'\berror(?::|\[|\s+[A-Z]+\d+\b)|\bfatal:|\bexception\b|'
        r'FAILURE:|What went wrong|Caused by:|Target .+ failed|Failed to',
        re.IGNORECASE,
    )
    selected = set()
    for index, line in enumerate(lines):
        if error.search(line):
            selected.update(range(max(0, index - 3), min(len(lines), index + 9)))
    if not selected:
        selected.update(range(max(0, len(lines) - max_lines), len(lines)))
    excerpt = [lines[index][:500] for index in sorted(selected)[:max_lines]]
    if len(selected) > max_lines:
        excerpt.append('[Excerpt limited; see the Setup step for full output.]')
    return '\n'.join(excerpt) or 'The packaging command produced no output.'


def main():
    log_path = Path(sys.argv[1])
    log = log_path.read_text(encoding='utf-8', errors='replace')
    excerpt = summarize_build_log(log, os.environ.get('VPN_RSA_PRIVATE_KEY_B64', ''))
    print(excerpt)
    summary_path = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary_path:
        with Path(summary_path).open('a', encoding='utf-8') as summary:
            summary.write('### Packaging failure\n\n```text\n')
            summary.write(excerpt.replace('```', "'''"))
            summary.write('\n```\n')


if __name__ == '__main__':
    main()
