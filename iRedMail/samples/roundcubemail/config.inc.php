<?php

// SQL DATABASE
$config['db_dsnw'] = 'PH_PHP_CONN_TYPE://PH_RCM_DB_USER:PH_RCM_DB_PASSWD@PH_SQL_SERVER/PH_RCM_DB';

// LOGGING
$config['log_driver'] = 'syslog';
$config['syslog_facility'] = LOG_MAIL;

// IMAP
//$config['default_host'] = 'localhost';
//$config['default_port'] = 143;
$config['imap_auth_type'] = 'LOGIN';
$config['imap_delimiter'] = '/';

// SMTP
$config['smtp_server'] = 'PH_SMTP_SERVER';
//$config['smtp_port'] = 25;
$config['smtp_user'] = '%u';
$config['smtp_pass'] = '%p';
$config['smtp_auth_type'] = 'LOGIN';

// SYSTEM
$config['force_https'] = true;
$config['login_autocomplete'] = 2;
$config['ip_check'] = true;
$config['des_key'] = 'PH_RCM_DES_KEY';
$config['useragent'] = 'Roundcube Webmail'; // Hide version number
//$config['username_domain'] = 'PH_FIRST_DOMAIN';
$config['identities_level'] = 3;

// USER INTERFACE
$config['create_default_folders'] = true;
$config['quota_zero_as_unlimited'] = true;

// USER PREFERENCES
$config['default_charset'] = 'UTF-8';
//$config['addressbook_sort_col'] = 'name';
$config['draft_autosave'] = 60;
$config['preview_pane'] = true;
$config['autoexpand_threads'] = 2;
$config['check_all_folders'] = true;

// PLUGINS
$config['plugins'] = array('managesieve', 'password');

