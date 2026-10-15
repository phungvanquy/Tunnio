# Encrypted subscription links

[← Back to the README](../README.md) · [User guide](../VPN_GUIDE.md) · [Build guide](BUILDING.md)

Tunnio accepts plain HTTP(S) subscription URLs and optional `tunnio-rsa:` links. An encrypted link contains a subscription
URL encrypted for a particular app build. The app saves the encrypted link and decrypts it when downloading or refreshing.

This feature conceals the URL during normal app use. It does not protect it from someone who can inspect the application
binary or device: the bundled private key and downloaded configuration can be extracted. Treat both plain and encrypted
subscription links as sensitive.

## Format

```text
tunnio-rsa:<unpadded base64url ciphertext>
```

| Property | Value |
| --- | --- |
| Plaintext | An HTTP(S) subscription URL encoded as UTF-8 |
| Encryption | RSA-OAEP |
| OAEP digest | SHA-256 |
| MGF1 digest | SHA-256 |
| Ciphertext encoding | URL-safe Base64, without `=` padding |

RSA-OAEP encrypts only short inputs directly. A 3072-bit key supports at most **318 UTF-8 bytes** with SHA-256. Use a
shorter subscription URL if needed; the limit is bytes, not characters.

## Create a key pair

Run these commands from the repository root with OpenSSL and Python 3 installed:

```bash
mkdir -p .local-keys
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 -out .local-keys/private.pem
openssl pkey -in .local-keys/private.pem -pubout -out .local-keys/public.pem
```

Keep the private key outside version control. `.local-keys/` and `env.local.json` are ignored by this repository.
Give only the public key to the person or service generating links.

## Configure the app build

Encode the PEM private key into the local build configuration. This updates the key field while retaining other existing
JSON fields:

```bash
python3 - <<'PY'
import base64
import json
from pathlib import Path

config_path = Path('env.local.json')
config = json.loads(config_path.read_text()) if config_path.exists() else {}
config['VPN_RSA_PRIVATE_KEY_B64'] = base64.b64encode(
    Path('.local-keys/private.pem').read_bytes()
).decode('ascii')
config_path.write_text(json.dumps(config, indent=2) + '\n')
PY
```

Choose the appropriate build path:

| Build path | Key configuration |
| --- | --- |
| `dart setup.dart <platform>` | Reads the key from `env.local.json` into generated `env.json`; the `VPN_RSA_PRIVATE_KEY_B64` environment variable takes precedence |
| Direct Flutter run or build | Pass `--dart-define-from-file=env.local.json` |
| GitHub Actions packages | Set the repository secret `VPN_RSA_PRIVATE_KEY_B64` to the Base64-encoded PEM private key |

For example, `flutter run --dart-define-from-file=env.local.json` includes the local key in a development build.
A build without a key still imports plain URLs and reports a missing key for encrypted links.

## Generate a link

```bash
python3 tool/encrypt_subscription_url.py --public-key .local-keys/public.pem
```

Enter one subscription URL on standard input, then press Enter. The tool prints the encrypted link. Import that complete
link into the app build containing the matching private key. Passing the URL through standard input avoids placing it
directly in the shell command history.

For the optional browser-based link generator and its deployment settings, see the [site documentation](../site/README.md).
Only the public key belongs in that site.

## Rotate keys

Existing links need the same private key for future refreshes. Before distributing a build with a new key, generate
replacement links with the new public key and arrange for users to reimport them. Replacing the build key alone makes
old encrypted subscriptions unreadable by that build.

| Symptom | Check |
| --- | --- |
| Missing key | The installed build must include `VPN_RSA_PRIVATE_KEY_B64`. |
| Decryption fails | Confirm that the link and app use the same key pair and the exact format above. |
| Encryption fails | Check the public-key file and the URL's UTF-8 byte length. |
| Import succeeds, but proxies fail | Decryption is only the import step; continue with [connection troubleshooting](../VPN_GUIDE.md#troubleshooting). |
