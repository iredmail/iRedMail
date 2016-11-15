// Global LDAP address book.
$config['ldap_public']["global_ldap_abook"] = array(
    'name'              => 'Global LDAP Address Book',
    'hosts'             => array('PH_LDAP_SERVER_HOST'),
    'port'              => PH_LDAP_SERVER_PORT,
    'use_tls'           => false,
    'ldap_version'      => '3',
    'network_timeout'   => 10,
    'user_specific'     => true,

    // Search mail users under same domain.
    'base_dn'       => 'domainName=%d,PH_LDAP_BASEDN',
    'bind_dn'       => 'mail=%u@%d,ou=Users,domainName=%d,PH_LDAP_BASEDN',

    'hidden'        => false,
    'searchonly'    => false,
    'writable'      => false,

    'search_fields' => array('mail', 'cn', 'sn', 'givenName', 'street', 'telephoneNumber', 'mobile', 'stree', 'postalCode'),

    // mapping of contact fields to directory attributes
    'fieldmap' => array(
        'name'          => 'cn',
        'surname'       => 'sn',
        'firstname'     => 'givenName',
        'title'         => 'title',
        'email'         => 'mail:*',
        'phone:work'    => 'telephoneNumber',
        'phone:mobile'  => 'mobile',
        'phone:workfax' => 'facsimileTelephoneNumber',
        'street'        => 'street',
        'zipcode'       => 'postalCode',
        'locality'      => 'l',
        'department'    => 'departmentNumber',
        'notes'         => 'description',
        'photo'         => 'jpegPhoto',
    ),
    'sort'          => 'cn',
    'scope'         => 'sub',
    'filter'        => '(&(enabledService=mail)(enabledService=deliver)(enabledService=displayedInGlobalAddressBook)(|(objectClass=mailUser)(objectClass=mailList)(objectClass=mailAlias)))',
    'fuzzy_search'  => true,
    'vlv'           => false,   // Enable Virtual List View to more efficiently fetch paginated data (if server supports it)
    'sizelimit'     => '0',     // Enables you to limit the count of entries fetched. Setting this to 0 means no limit.
    'timelimit'     => '0',     // Sets the number of seconds how long is spend on the search. Setting this to 0 means no limit.
    'referrals'     => false,  // Sets the LDAP_OPT_REFERRALS option. Mostly used in multi-domain Active Directory setups

    'group_filters' => array(
        'departments' => array(
            'name'    => 'Mailing Lists',
            'scope'   => 'sub',
            'base_dn' => 'domainName=%d,PH_LDAP_BASEDN',
            'filter'  => '(&(|(objectclass=mailList)(objectClass=mailAlias))(accountStatus=active)(enabledService=displayedInGlobalAddressBook))',
            'name_attr' => 'cn',
            'email'     => 'mail',
        ),
    ),
);
$config['autocomplete_addressbooks'] = array('sql', 'global_ldap_abook');
