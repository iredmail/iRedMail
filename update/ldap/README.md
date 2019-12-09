# Update LDAP data

[TOC]

## Summary

If you're restoring from an old iRedMail release, you need to add missing LDAP
attribute/values, which are introduced in new iRedMail releases, by running
Python scripts below: <https://github.com/iredmail/iredmail/tree/master/update/>.

For example:

* If you're restoring iRedMail from `0.9.1` to `0.9.5`, you must run all update
  scripts for iRedMail-0.9.1 and newer releases. In this case, only file
  `updateLDAPValues_094_to_095.py` listed in above link is required.

* If you're restoring iRedMail from `0.8.6` to `0.9.5`, you need 3 files:

    * `updateLDAPValues_086_to_087.py`
    * `updateLDAPValues_087_to_090.py`
    * `updateLDAPValues_094_to_095.py`

## How to use those upgrade scripts

Please open the file you need to run, for example, `updateLDAPValues_094_to_095.py`,
find parameters like below:

```
uri = 'ldap://127.0.0.1:389'
basedn = 'o=domains,dc=example,dc=com'
bind_dn = 'cn=Manager,dc=example,dc=com'
bind_pw = 'passwd'
```

Please update them with the correct LDAP prefix (`dc=xx,dc=xx`) and bind
password, then run it with `python` command:

```
python updateLDAPValues_094_to_095.py
```
