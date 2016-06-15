-- Delete anonymouse user.
USE mysql;

DELETE FROM user WHERE User='';
DELETE FROM db WHERE User='';

FLUSH PRIVILEGES;
