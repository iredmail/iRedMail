import os
import sys
from base64 import b64encode

def generate_ssha_password(p):
    p = str(p).strip()
    salt = os.urandom(8)
    try:
        from hashlib import sha1
        pw = sha1(p)
    except ImportError:
        import sha
        pw = sha.new(p)
    pw.update(salt)
    return "{SSHA}" + b64encode(pw.digest() + salt)

print generate_ssha_password(sys.argv[1])
