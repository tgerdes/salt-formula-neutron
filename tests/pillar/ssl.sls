include:
  - .control_cluster

neutron:
  server:
    database:
      ssl:
        enabled: True
    message_queue:
      port: 5671
      ssl:
        enabled: True
