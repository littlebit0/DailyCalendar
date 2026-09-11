#!/usr/bin/env python3
"""One-time maintainer setup; requires PGPy. Private material stays outside git."""
import os
import pathlib

import pgpy
from pgpy.constants import PubKeyAlgorithm, KeyFlags, HashAlgorithm, SymmetricKeyAlgorithm, CompressionAlgorithm

os.umask(0o077)
directory = pathlib.Path.home() / ".local/share/daily-signing/linux-apt"
directory.mkdir(parents=True, exist_ok=True, mode=0o700)
private_path = directory / "archive-private.asc"
if private_path.exists():
    raise SystemExit("A signing key already exists; do not rotate it implicitly.")
key = pgpy.PGPKey.new(PubKeyAlgorithm.RSAEncryptOrSign, 4096)
key.add_uid(pgpy.PGPUID.new("DailyCalendar Linux Archive"),
            usage={KeyFlags.Certify, KeyFlags.Sign}, hashes=[HashAlgorithm.SHA256],
            ciphers=[SymmetricKeyAlgorithm.AES256], compression=[CompressionAlgorithm.ZLIB])
private_path.write_text(str(key))
public_path = pathlib.Path(__file__).resolve().parents[2] / "packaging/linux/dailycalendar-archive-keyring.asc"
public_path.write_text(str(key.pubkey))
public_path.chmod(0o644)
print(f"Public fingerprint: {key.fingerprint}")
