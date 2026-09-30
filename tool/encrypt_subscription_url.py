#!/usr/bin/env python3
"""Encrypt one subscription URL from stdin for Tunnio import."""

import argparse
import base64
import subprocess
import sys
from urllib.parse import urlsplit


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--public-key', required=True, help='RSA public PEM path')
    args = parser.parse_args()

    url = sys.stdin.readline().rstrip('\r\n')
    parsed = urlsplit(url)
    if parsed.scheme not in ('http', 'https') or not parsed.hostname:
        parser.error('stdin must contain one HTTP or HTTPS URL')

    result = subprocess.run(
        [
            'openssl', 'pkeyutl', '-encrypt', '-pubin', '-inkey', args.public_key,
            '-pkeyopt', 'rsa_padding_mode:oaep',
            '-pkeyopt', 'rsa_oaep_md:sha256',
            '-pkeyopt', 'rsa_mgf1_md:sha256',
        ],
        input=url.encode('utf-8'),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode:
        parser.error('encryption failed; check the key and URL length')

    token = base64.urlsafe_b64encode(result.stdout).rstrip(b'=').decode('ascii')
    print(f'tunnio-rsa:{token}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
