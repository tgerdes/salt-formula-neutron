neutron:
  server:
    api_workers: 2
    rpc_workers: 2
    rpc_state_report_workers: 2
    backend:
      engine: ml2
      external_mtu: 1500
      mechanism:
        ovs:
          driver: openvswitch
      tenant_network_types: flat,vxlan
    bind:
      address: 172.16.10.101
      port: 9696
    compute:
      host: 127.0.0.1
      password: workshop
      region: RegionOne
      tenant: service
      user: nova
    database:
      engine: mysql
      host: 127.0.0.1
      name: neutron
      password: workshop
      port: 3306
      user: neutron
    version: ocata
    dns_domain: novalocal
    dvr: false
    enabled: true
    global_physnet_mtu: 1500
    identity:
      engine: keystone
      host: 127.0.0.1
      password: workshop
      port: 35357
      region: RegionOne
      tenant: service
      user: neutron
      endpoint_type: internal
    l3_ha: false
    message_queue:
      engine: rabbitmq
      host: 127.0.0.1
      password: workshop
      port: 5672
      user: openstack
      virtual_host: /openstack
    policy:
      create_subnet: 'rule:admin_or_network_owner'
      'get_network:queue_id': 'rule:admin_only'
      'create_network:shared':
  fwaas:
    enabled: true
    version: ocata
    api_version: v1
