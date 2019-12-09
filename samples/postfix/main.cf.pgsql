#
# Lookup virtual mail accounts
#
transport_maps =
    proxy:pgsql:PH_POSTFIX_LOOKUP_DIR/transport_maps_user.cf
    proxy:pgsql:PH_POSTFIX_LOOKUP_DIR/transport_maps_maillist.cf
    proxy:pgsql:PH_POSTFIX_LOOKUP_DIR/transport_maps_domain.cf

sender_dependent_relayhost_maps =
    proxy:pgsql:PH_POSTFIX_LOOKUP_DIR/sender_dependent_relayhost_maps.cf

# Lookup table with the SASL login names that own the sender (MAIL FROM) addresses.
smtpd_sender_login_maps =
    proxy:pgsql:PH_POSTFIX_LOOKUP_DIR/sender_login_maps.cf

virtual_mailbox_domains =
    proxy:pgsql:PH_POSTFIX_LOOKUP_DIR/virtual_mailbox_domains.cf

relay_domains =
    $mydestination
    proxy:pgsql:PH_POSTFIX_LOOKUP_DIR/relay_domains.cf

virtual_mailbox_maps =
    proxy:pgsql:PH_POSTFIX_LOOKUP_DIR/virtual_mailbox_maps.cf

virtual_alias_maps =
    proxy:pgsql:PH_POSTFIX_LOOKUP_DIR/virtual_alias_maps.cf
    proxy:pgsql:PH_POSTFIX_LOOKUP_DIR/domain_alias_maps.cf
    proxy:pgsql:PH_POSTFIX_LOOKUP_DIR/catchall_maps.cf
    proxy:pgsql:PH_POSTFIX_LOOKUP_DIR/domain_alias_catchall_maps.cf

sender_bcc_maps =
    proxy:pgsql:PH_POSTFIX_LOOKUP_DIR/sender_bcc_maps_user.cf
    proxy:pgsql:PH_POSTFIX_LOOKUP_DIR/sender_bcc_maps_domain.cf

recipient_bcc_maps =
    proxy:pgsql:PH_POSTFIX_LOOKUP_DIR/recipient_bcc_maps_user.cf
    proxy:pgsql:PH_POSTFIX_LOOKUP_DIR/recipient_bcc_maps_domain.cf

