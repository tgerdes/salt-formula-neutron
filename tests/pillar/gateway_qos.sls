neutron:
  gateway:
    agent_mode: legacy
    backend:
      engine: ml2
      tenant_network_types: "flat,vxlan"
      mechanism:
        - openvswitch
        - l2population
    dvr: false
    enabled: true
    qos: true
    external_access: True
    local_ip: 10.1.0.110
    message_queue:
      engine: rabbitmq
      host: 127.0.0.1
      password: workshop
      port: 5672
      user: openstack
      virtual_host: /openstack
    metadata:
      host: 127.0.0.1
      password: password
    version: ocata
