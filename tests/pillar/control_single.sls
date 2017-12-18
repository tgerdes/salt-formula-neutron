neutron:
  server:
    api_workers: 2
    rpc_workers: 2
    rpc_state_report_workers: 2
    enabled: true
    backend:
      external_mtu: 1500
      tenant_net_mtu: 9000
      ironic_net_mtu: 9000
      engine: contrail
      #contrail_discovery_host
      host: 127.0.0.1
      port: 8082
      user: admin
      password: password
      token: token
      tenant: admin
    fwaas: false
    dns_domain: novalocal
    tunnel_type: vxlan
    version: liberty
    bind:
      address: 127.0.0.1
      port: 9696
    database:
      engine: mysql
      host: 127.0.0.1
      port: 3306
      name: neutron
      user: neutron
      password: password
    identity:
      engine: keystone
      region: RegionOne
      host: 127.0.0.1
      port: 35357
      user: neutron
      password: password
      tenant: service
      endpoint_type: internal
    message_queue:
      engine: rabbitmq
      host: 127.0.0.1
      port: 5672
      user: openstack
      password: password
      virtual_host: '/openstack'
    compute:
      host: 127.0.0.1
      region: RegionOne
      user: nova
      password: password
      tenant: service
    policy:
      create_subnet: 'rule:admin_or_network_owner'
      'get_network:queue_id': 'rule:admin_only'
      'create_network:shared':
