neutron:
  compute:
    enabled: true
    version: ocata
    local_ip: 10.2.0.105
    controller_vip: 10.1.0.101
    external_access: false
    backend:
      engine: ovn
