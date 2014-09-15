"""Avaiable password schemes: BCRYPT, SSHA, MD5."""

import os
import sys
import subprocess
from base64 import b64encode


def generate_bcrypt_password(p):
    try:
        import bcrypt
    except:
        return generate_ssha_password(p)

    return '{CRYPT}' + bcrypt.hashpw(p, bcrypt.gensalt())


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


def generate_md5_password(p):
    p = str(p).strip()
    return subprocess.check_output(['openssl', 'passwd', '-1', p])


if __name__ == '__main__':
    scheme = sys.argv[1]
    password = sys.argv[2]
    if scheme == 'BCRYPT':
        print generate_bcrypt_password(password)
    elif scheme == 'SSHA':
        print generate_ssha_password(password)
    elif scheme == 'MD5':
        print generate_md5_password(password)
    else:
        print generate_ssha_password(password)
