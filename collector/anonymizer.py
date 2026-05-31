"""
anonymizer.py
-------------
MAC adreslerini KVKK uyumlu şekilde anonimleştiren yardımcı modül.

Politika:
- Ham MAC adresi hiçbir zaman log'a, veritabanına veya yanıta yazılmaz.
- Tek yönlü SHA-256 hash + salt ile pseudonim üretilir.
- Hash her seferinde aynı MAC için aynı sonucu üretir (cihaz takibi için)
  ancak hash'ten MAC'e geri dönüş mümkün değildir.
"""

from __future__ import annotations

import hashlib
import os

# Salt rastgele üretilir veya env'den okunur. Üretimde mutlaka env ile sabit
# tutulmalı, aksi takdirde her servis restartında farklı hash'ler üretilir.
_DEFAULT_SALT = "campus-occupancy-anonymizer-v1"
_SALT = os.getenv("ANONYMIZER_SALT", _DEFAULT_SALT).encode("utf-8")


def hash_mac(mac_address: str) -> str:
    """
    MAC adresini SHA-256 ile hash'leyerek anonim cihaz kimliği üretir.

    Args:
        mac_address: Ham MAC adresi (örn. "AA:BB:CC:DD:EE:FF")

    Returns:
        Hex formatında 64 karakterlik anonim hash
    """
    if not mac_address:
        raise ValueError("MAC adresi boş olamaz")
    normalized = mac_address.strip().lower().replace("-", ":")
    digest = hashlib.sha256(_SALT + normalized.encode("utf-8")).hexdigest()
    return digest


def hash_macs(mac_list: list[str]) -> set[str]:
    """Birden fazla MAC adresini hash'leyip benzersiz set döner."""
    return {hash_mac(mac) for mac in mac_list if mac}
