# apple_store.py
# Verifies Apple App Store JWS transaction tokens from StoreKit 2.
# Uses only libraries already in requirements.txt (cryptography, pyjwt[crypto]).
#
# Flow:
#   1. Parse the JWS header to get the x5c certificate chain
#   2. Verify the chain terminates at an Apple Root CA
#   3. Verify each cert is signed by its parent
#   4. Verify the JWS signature using the leaf cert's EC public key
#   5. Decode the payload and verify bundle ID + active subscription

import base64
import json
import os
from datetime import datetime, timezone

from cryptography import x509
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives.asymmetric.ec import ECDSA
from cryptography.hazmat.primitives.asymmetric.rsa import RSAPublicKey
from cryptography.hazmat.primitives.asymmetric.padding import PKCS1v15
from cryptography.hazmat.primitives.hashes import SHA256, SHA384, SHA512
from cryptography.exceptions import InvalidSignature


BUNDLE_ID = os.getenv("APPLE_CLIENT_ID", "OrgIdentifier.ai-anti-doomscroll")


def _b64url_decode(s: str) -> bytes:
    """Decode a base64url-encoded string (no padding required)."""
    s += "=" * (4 - len(s) % 4)
    return base64.urlsafe_b64decode(s)


def _decode_payload_unverified(payload_b64: str) -> dict:
    """Decode the JWS payload without signature verification (used to peek at environment)."""
    try:
        return json.loads(_b64url_decode(payload_b64))
    except Exception:
        raise ValueError("Failed to decode JWS payload")


def verify_app_store_jws(jws_token: str) -> dict:
    """
    Verify an Apple App Store JWS transaction token (StoreKit 2).

    - Production / Sandbox (real Apple-signed): full certificate chain + signature verification.
    - Xcode (local StoreKit testing): payload-only validation; cert chain is Xcode-generated
      and intentionally not from Apple's CA, so cryptographic verification is skipped.

    Returns the decoded payload dict on success.
    Raises ValueError with a descriptive message on any failure.
    """
    parts = jws_token.strip().split(".")
    if len(parts) != 3:
        raise ValueError("Malformed JWS: expected header.payload.signature")

    header_b64, payload_b64, signature_b64 = parts

    # ── 1. Parse header ────────────────────────────────────────────────────
    try:
        header = json.loads(_b64url_decode(header_b64))
    except Exception:
        raise ValueError("Failed to decode JWS header")

    if header.get("alg") != "ES256":
        raise ValueError(f"Unexpected JWS algorithm: {header.get('alg')}")

    # ── 2. Peek at payload to detect environment before cert verification ──
    # Xcode local StoreKit testing produces environment="Xcode"; those tokens
    # are signed by an Xcode-generated cert, not Apple's CA.  We skip chain
    # verification for them but still validate bundle ID and expiry.
    payload = _decode_payload_unverified(payload_b64)
    environment = payload.get("environment", "Production")

    if environment == "Xcode":
        print(f"ℹ️  [verify_jws] Xcode StoreKit environment — skipping cert chain verification")
    else:
        # ── 3. Load certificate chain ──────────────────────────────────────
        x5c = header.get("x5c", [])
        if len(x5c) < 2:
            raise ValueError("JWS must contain a certificate chain of at least 2 certs")

        certs = []
        for cert_b64 in x5c:
            try:
                cert_bytes = base64.b64decode(cert_b64)  # x5c uses standard base64
                cert = x509.load_der_x509_certificate(cert_bytes, default_backend())
                certs.append(cert)
            except Exception as e:
                raise ValueError(f"Failed to parse certificate in chain: {e}")

        # ── 4. Verify root is an Apple CA ──────────────────────────────────
        root_cert = certs[-1]
        cn_attrs = root_cert.subject.get_attributes_for_oid(x509.NameOID.COMMON_NAME)
        root_cn = cn_attrs[0].value if cn_attrs else ""
        if "Apple" not in root_cn:
            raise ValueError(f"Root certificate is not an Apple CA: '{root_cn}'")

        # ── 5. Verify each cert is signed by the next in the chain ────────
        # Apple Sandbox uses RSA-signed intermediates; Production uses ECDSA.
        # We detect the parent key type and pick the right verifier.
        def _hash_for_algo(algo_oid):
            """Map signature algorithm OID to a hash object."""
            oid_str = algo_oid.dotted_string
            if "384" in oid_str:
                return SHA384()
            if "512" in oid_str:
                return SHA512()
            return SHA256()

        for i in range(len(certs) - 1):
            child = certs[i]
            parent = certs[i + 1]
            parent_key = parent.public_key()
            hash_algo = _hash_for_algo(child.signature_algorithm_oid)
            try:
                if isinstance(parent_key, RSAPublicKey):
                    parent_key.verify(
                        child.signature,
                        child.tbs_certificate_bytes,
                        PKCS1v15(),
                        hash_algo,
                    )
                else:
                    parent_key.verify(
                        child.signature,
                        child.tbs_certificate_bytes,
                        ECDSA(hash_algo),
                    )
            except InvalidSignature:
                raise ValueError(f"Certificate chain broken at index {i}")
            except Exception as e:
                raise ValueError(f"Certificate chain verification error: {e}")

        # ── 6. Verify JWS signature with leaf cert's public key ───────────
        leaf_public_key = certs[0].public_key()
        signing_input = f"{header_b64}.{payload_b64}".encode("utf-8")
        try:
            signature_bytes = _b64url_decode(signature_b64)
            leaf_public_key.verify(signature_bytes, signing_input, ECDSA(SHA256()))
        except InvalidSignature:
            raise ValueError("JWS signature is invalid — token has been tampered with")
        except Exception as e:
            raise ValueError(f"Signature verification error: {e}")

        print(f"✅ [verify_jws] {environment} cert chain + signature verified")

    # ── 7. Validate bundle ID ──────────────────────────────────────────────
    if payload.get("bundleId") != BUNDLE_ID:
        raise ValueError(
            f"Bundle ID mismatch: expected '{BUNDLE_ID}', got '{payload.get('bundleId')}'"
        )

    # ── 8. Check subscription is not expired ───────────────────────────────
    # expiresDate is in milliseconds since epoch (present for auto-renewable subs)
    expires_ms = payload.get("expiresDate")
    if expires_ms is not None:
        expires_at = datetime.fromtimestamp(expires_ms / 1000, tz=timezone.utc)
        if expires_at < datetime.now(tz=timezone.utc):
            raise ValueError(
                f"Subscription expired at {expires_at.isoformat()}"
            )

    return payload
