-- Bypass greylisting for big ISPs.
-- To contribute, please
-- 1) Create a new topic in our online support forum: http://www.iredmail.org/forum/
-- 2) Or, open an issue in https://bitbucket.org/zhb/iredmail/issues

INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:216.239.32.0/19','GOOGLE',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:64.233.160.0/19','GOOGLE',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:66.249.80.0/20','GOOGLE',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:72.14.192.0/18','GOOGLE',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:209.85.128.0/17','GOOGLE',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:66.102.0.0/20','GOOGLE',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:74.125.0.0/16','GOOGLE',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:64.18.0.0/20','GOOGLE',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:207.126.144.0/20','GOOGLE',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:173.194.0.0/16','GOOGLE',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:65.54.190.0/26','MICROSOFT',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:65.54.190.64/26','MICROSOFT',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:65.54.190.128/26','MICROSOFT',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:65.54.190.192/26','MICROSOFT',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:65.55.116.0/26','MICROSOFT',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:65.55.111.64/26','MICROSOFT',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:65.55.116.64/26','MICROSOFT',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:65.55.111.128/26','MICROSOFT',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:65.55.34.0/26','MICROSOFT',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:65.55.34.64/26','MICROSOFT',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:65.55.34.128/26','MICROSOFT',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:65.55.34.192/26','MICROSOFT',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:65.55.90.0/26','MICROSOFT',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:65.55.90.64/26','MICROSOFT',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:65.55.90.128/26','MICROSOFT',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:65.55.90.192/26','MICROSOFT',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:65.54.51.64/26','MICROSOFT',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:65.54.61.64/26','MICROSOFT',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:207.46.66.0/28','MICROSOFT',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:157.55.0.192/26','MICROSOFT',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:157.55.1.128/26','MICROSOFT',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:157.55.2.0/26','MICROSOFT',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:157.55.2.64/26','MICROSOFT',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:69.63.179.25','FACEBOOK',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:69.63.178.128/25','FACEBOOK',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:69.63.184.0/25','FACEBOOK',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:66.220.144.128/25','FACEBOOK',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:66.220.155.0/24','FACEBOOK',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:69.171.232.128/25','FACEBOOK',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:66.220.157.0/25','FACEBOOK',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:69.171.244.0/24','FACEBOOK',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:199.16.156.0/22','TWITTER',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:199.59.148.0/22','TWITTER',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:8.25.194.26/31','TWITTER',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:204.92.114.203','TWITTER',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:204.92.114.204/31','TWITTER',0);

-- Below records come from Cluebringer package
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:127.0.0.0/8','Local loopback address',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:192.168.0.0/8','Local loopback address',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:10.0.0.0/8','Local loopback address',0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:172.16.0.0/12','Local loopback address',0);
-- Cluebringer: Servers that don't like greylisting
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:12.5.136.141', 'Southwest Airlines (unique sender, no retry)', 0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:12.5.136.142', 'Southwest Airlines (unique sender, no retry)', 0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:12.5.136.143', 'Southwest Airlines (unique sender, no retry)', 0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:12.5.136.144', 'Southwest Airlines (unique sender, no retry)', 0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:63.169.44.143', 'Southwest Airlines (unique sender, no retry)', 0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:63.169.44.144', 'Southwest Airlines (unique sender, no retry)', 0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:12.107.209.244', 'kernel.org mailing lists (high traffic, unique sender per mail)', 0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:64.124.204.39', 'moveon.org (unique sender per attempt)', 0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:64.125.132.254', 'collab.net (unique sender per attempt)', 0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:66.135.209.0/24', 'Ebay (for time critical alerts)', 0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:66.218.66.0/24', 'Yahoo Groups servers (common pool, no retry)', 0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:66.218.67.0/24', 'Yahoo Groups servers (common pool, no retry)', 0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:66.218.69.0/24', 'Yahoo Groups servers (common pool, no retry)', 0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:66.94.237.0/24', 'Yahoo Groups servers (common pool, no retry)', 0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:204.107.120.10', 'Ameritrade (no retry)', 0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:207.115.63.0/24', 'Prodigy (broken software that retries continually with no delay)', 0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:205.206.231.0/24', 'SecurityFocus.com (unique sender per attempt)', 0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:209.132.176.174', 'Sourceware.org mailing lists (high traffic, unique sender per mail)', 0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:211.29.132.0/24', 'optusnet.com.au (wierd retry pattern and more than 48hrs)', 0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:213.136.52.31', 'Mysql.com (unique sender)', 0);
INSERT INTO greylisting_whitelist (Source,Comment,Disabled) VALUES ('SenderIP:217.158.50.178', 'AXKit mailing list (unique sender per attempt)', 0);
