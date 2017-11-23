===============
Neutron Formula
===============

Neutron is an OpenStack project to provide "networking as a service" between
interface devices (e.g., vNICs) managed by other Openstack services (e.g.,
nova).

Starting in the Folsom release, Neutron is a core and supported part of the
OpenStack platform (for Essex, we were an "incubated" project, which means use
is suggested only for those who really know what they're doing with Neutron).

Sample Pillars
==============

Neutron Server on the controller node

.. code-block:: yaml

    neutron:
      server:
        enabled: true
        version: mitaka
        allow_pagination: true
        pagination_max_limit: 100
        bind:
          address: 172.20.0.1
          port: 9696
        database:
          engine: mysql
          host: 127.0.0.1
          port: 3306
          name: neutron
          user: neutron
          password: pwd
        identity:
          engine: keystone
          host: 127.0.0.1
          port: 35357
          user: neutron
          password: pwd
          tenant: service
          endpoint_type: internal
        message_queue:
          engine: rabbitmq
          host: 127.0.0.1
          port: 5672
          user: openstack
          password: pwd
          virtual_host: '/openstack'
        metadata:
          host: 127.0.0.1
          port: 8775
          password: pass
        audit:
          enabled: false

Note: The pagination is useful to retrieve a large bunch of resources,
because a single request may fail (timeout). This is enabled with both
parameters *allow_pagination* and *pagination_max_limit* as shown above.


Configuration of policy.json file

.. code-block:: yaml

    neutron:
      server:
        ....
        policy:
          create_subnet: 'rule:admin_or_network_owner'
          'get_network:queue_id': 'rule:admin_only'
          # Add key without value to remove line from policy.json
          'create_network:shared':

Neutron LBaaSv2 enablement
--------------------------

.. code-block:: yaml

  neutron:
    server:
      lbaas:
        enabled: true
        providers:
          octavia:
            engine: octavia
            driver_path: 'neutron_lbaas.drivers.octavia.driver.OctaviaDriver'
            base_url: 'http://127.0.0.1:9876'
          avi_adc:
            engine: avinetworks
            driver_path: 'avi_lbaasv2.avi_driver.AviDriver'
            controller_address: 10.182.129.239
            controller_user: admin
            controller_password: Cloudlab2016
            controller_cloud_name: Default-Cloud
          avi_adc2:
            engine: avinetworks
            ...

Note: If the Contrail backend is set, Opencontrail loadbalancer would be enabled
automatically. In this case lbaas should disabled in pillar:

.. code-block:: yaml

  neutron:
    server:
      lbaas:
        enabled: false


Neutron FWaaSv1 enablement
--------------------------

.. code-block:: yaml

  neutron:
    fwaas:
      enabled: true
      version: ocata
      api_version: v1


Enable CORS parameters
----------------------

.. code-block:: yaml

    neutron:
      server:
        cors:
          allowed_origin: https:localhost.local,http:localhost.local
          expose_headers: X-Auth-Token,X-Openstack-Request-Id,X-Subject-Token
          allow_methods: GET,PUT,POST,DELETE,PATCH
          allow_headers: X-Auth-Token,X-Openstack-Request-Id,X-Subject-Token
          allow_credentials: True
          max_age: 86400


Neutron VXLAN tenant networks with Network nodes
------------------------------------------------

With DVR for East-West and Network node for North-South.

This use case describes a model utilising VxLAN overlay with DVR. The DVR
routers will only be utilized for traffic that is router within the cloud
infrastructure and that remains encapsulated. External traffic will be
routed to via the network nodes.

The intention is that each tenant will require at least two (2) vrouters
one to be utilised

Neutron Server

.. code-block:: yaml

    neutron:
      server:
        version: mitaka
        path_mtu: 1500
        bind:
          address: 172.20.0.1
          port: 9696
        database:
          engine: mysql
          host: 127.0.0.1
          port: 3306
          name: neutron
          user: neutron
          password: pwd
        identity:
          engine: keystone
          host: 127.0.0.1
          port: 35357
          user: neutron
          password: pwd
          tenant: service
          endpoint_type: internal
        message_queue:
          engine: rabbitmq
          host: 127.0.0.1
          port: 5672
          user: openstack
          password: pwd
          virtual_host: '/openstack'
        global_physnet_mtu: 9000
        l3_ha: False # Which type of router will be created by default
        dvr: True # disabled for non DVR use case
        backend:
          engine: ml2
          tenant_network_types: "flat,vxlan"
          external_mtu: 9000
          mechanism:
            ovs:
              driver: openvswitch

Network Node

.. code-block:: yaml

    neutron:
      gateway:
        enabled: True
        version: mitaka
        message_queue:
          engine: rabbitmq
          host: 127.0.0.1
          port: 5672
          user: openstack
          password: pwd
          virtual_host: '/openstack'
        local_ip: 192.168.20.20 # br-mesh ip address
        dvr: True # disabled for non DVR use case
        agent_mode: dvr_snat
        metadata:
          host: 127.0.0.1
          password: pass
        backend:
          engine: ml2
          tenant_network_types: "flat,vxlan"
          mechanism:
            ovs:
              driver: openvswitch

Compute Node

.. code-block:: yaml

    neutron:
      compute:
        enabled: True
        version: mitaka
        message_queue:
          engine: rabbitmq
          host: 127.0.0.1
          port: 5672
          user: openstack
          password: pwd
          virtual_host: '/openstack'
        local_ip: 192.168.20.20 # br-mesh ip address
        dvr: True # disabled for non DVR use case
        agent_mode: dvr
        external_access: false # Compute node with DVR for east-west only, Network Node has True as default
        metadata:
          host: 127.0.0.1
          password: pass
        backend:
          engine: ml2
          tenant_network_types: "flat,vxlan"
          mechanism:
            ovs:
              driver: openvswitch
        audit:
          enabled: false


Disable physnet1 bridge
-----------------------

By default we have external access turned on, so among any physnets in
your reclass there would be additional one: physnet1, which is mapped to
br-floating

If you need internal nets only without this bridge, remove br-floating
and configurations mappings. Disable mappings for this bridge on
neutron-servers:

.. code-block:: yaml

    neutron:
      server:
        external_access: false

gateways:

.. code-block:: yaml

    neutron:
      gateway:
        external_access: false

compute nodes:

.. code-block:: yaml

    neutron:
      compute:
        external_access: false


Specify different mtu values for different physnets
---------------------------------------------------

Neutron Server

.. code-block:: yaml

    neutron:
      server:
        version: mitaka
        backend:
          external_mtu: 1500
          tenant_net_mtu: 9000
          ironic_net_mtu: 9000

Neutron VXLAN tenant networks with Network Nodes (non DVR)
----------------------------------------------------------

This section describes a network solution that utilises VxLAN overlay
 networks without DVR with all routers being managed on the network nodes.

Neutron Server

.. code-block:: yaml

    neutron:
      server:
        version: mitaka
        bind:
          address: 172.20.0.1
          port: 9696
        database:
          engine: mysql
          host: 127.0.0.1
          port: 3306
          name: neutron
          user: neutron
          password: pwd
        identity:
          engine: keystone
          host: 127.0.0.1
          port: 35357
          user: neutron
          password: pwd
          tenant: service
          endpoint_type: internal
        message_queue:
          engine: rabbitmq
          host: 127.0.0.1
          port: 5672
          user: openstack
          password: pwd
          virtual_host: '/openstack'
        global_physnet_mtu: 9000
        l3_ha: True
        dvr: False
        backend:
          engine: ml2
          tenant_network_types= "flat,vxlan"
          external_mtu: 9000
          mechanism:
            ovs:
              driver: openvswitch

Network Node

.. code-block:: yaml

    neutron:
      gateway:
        enabled: True
        version: mitaka
        message_queue:
          engine: rabbitmq
          host: 127.0.0.1
          port: 5672
          user: openstack
          password: pwd
          virtual_host: '/openstack'
        local_ip: 192.168.20.20 # br-mesh ip address
        dvr: False
        agent_mode: legacy
        availability_zone: az1
        metadata:
          host: 127.0.0.1
          password: pass
        backend:
          engine: ml2
          tenant_network_types: "flat,vxlan"
          mechanism:
            ovs:
              driver: openvswitch

Compute Node

.. code-block:: yaml

    neutron:
      compute:
        enabled: True
        version: mitaka
        message_queue:
          engine: rabbitmq
          host: 127.0.0.1
          port: 5672
          user: openstack
          password: pwd
          virtual_host: '/openstack'
        local_ip: 192.168.20.20 # br-mesh ip address
        external_access: False
        dvr: False
        backend:
          engine: ml2
          tenant_network_types: "flat,vxlan"
          mechanism:
            ovs:
              driver: openvswitch

Neutron VXLAN tenant networks with Network Nodes with DVR
---------------------------------------------------------

With DVR for East-West and North-South, DVR everywhere, Network node for SNAT.

This section describes a network solution that utilises VxLAN
overlay networks with DVR with North-South and East-West. Network
Node is used only for SNAT.

Neutron Server

.. code-block:: yaml

    neutron:
      server:
        version: mitaka
        bind:
          address: 172.20.0.1
          port: 9696
        database:
          engine: mysql
          host: 127.0.0.1
          port: 3306
          name: neutron
          user: neutron
          password: pwd
        identity:
          engine: keystone
          host: 127.0.0.1
          port: 35357
          user: neutron
          password: pwd
          tenant: service
          endpoint_type: internal
        message_queue:
          engine: rabbitmq
          host: 127.0.0.1
          port: 5672
          user: openstack
          password: pwd
          virtual_host: '/openstack'
        global_physnet_mtu: 9000
        l3_ha: False
        dvr: True
        backend:
          engine: ml2
          tenant_network_types= "flat,vxlan"
          external_mtu: 9000
          mechanism:
            ovs:
              driver: openvswitch

Network Node

.. code-block:: yaml

    neutron:
      gateway:
        enabled: True
        version: mitaka
        message_queue:
          engine: rabbitmq
          host: 127.0.0.1
          port: 5672
          user: openstack
          password: pwd
          virtual_host: '/openstack'
        local_ip: 192.168.20.20 # br-mesh ip address
        dvr: True
        agent_mode: dvr_snat
        availability_zone: az1
        metadata:
          host: 127.0.0.1
          password: pass
        backend:
          engine: ml2
          tenant_network_types: "flat,vxlan"
          mechanism:
            ovs:
              driver: openvswitch

Compute Node

.. code-block:: yaml

    neutron:
      compute:
        enabled: True
        version: mitaka
        message_queue:
          engine: rabbitmq
          host: 127.0.0.1
          port: 5672
          user: openstack
          password: pwd
          virtual_host: '/openstack'
        local_ip: 192.168.20.20 # br-mesh ip address
        dvr: True
        external_access: True
        agent_mode: dvr
        availability_zone: az1
        metadata:
          host: 127.0.0.1
          password: pass
        backend:
          engine: ml2
          tenant_network_types: "flat,vxlan"
          mechanism:
            ovs:
              driver: openvswitch

Sample Linux network configuration for DVR

.. code-block:: yaml

    linux:
      network:
        bridge: openvswitch
        interface:
          eth1:
            enabled: true
            type: eth
            mtu: 9000
            proto: manual
          eth2:
            enabled: true
            type: eth
            mtu: 9000
            proto: manual
          eth3:
            enabled: true
            type: eth
            mtu: 9000
            proto: manual
          br-int:
            enabled: true
            mtu: 9000
            type: ovs_bridge
          br-floating:
            enabled: true
            mtu: 9000
            type: ovs_bridge
          float-to-ex:
            enabled: true
            type: ovs_port
            mtu: 65000
            bridge: br-floating
          br-mgmt:
            enabled: true
            type: bridge
            mtu: 9000
            address: ${_param:single_address}
            netmask: 255.255.255.0
            use_interfaces:
            - eth1
          br-mesh:
            enabled: true
            type: bridge
            mtu: 9000
            address: ${_param:tenant_address}
            netmask: 255.255.255.0
            use_interfaces:
            - eth2
          br-ex:
            enabled: true
            type: bridge
            mtu: 9000
            address: ${_param:external_address}
            netmask: 255.255.255.0
            use_interfaces:
            - eth3
            use_ovs_ports:
            - float-to-ex

Additonal VXLAN tenant network settings
---------------------------------------

The default multicast group of 224.0.0.1 only multicasts to a single subnet.
Allow overriding it to allow larger underlay network topologies.

Neutron Server

.. code-block:: yaml

    neutron:
      server:
        vxlan:
          group: 239.0.0.0/8
          vni_ranges: "2:65535"

Neutron VLAN tenant networks with Network Nodes
-----------------------------------------------

VLAN tenant provider

Neutron Server only

.. code-block:: yaml

    neutron:
      server:
        version: mitaka
        ...
        global_physnet_mtu: 9000
        l3_ha: False
        dvr: True
        backend:
          engine: ml2
          tenant_network_types: "flat,vlan" # Can be mixed flat,vlan,vxlan
          tenant_vlan_range: "1000:2000"
          external_vlan_range: "100:200" # Does not have to be defined.
          external_mtu: 9000
          mechanism:
            ovs:
              driver: openvswitch

Compute node

.. code-block:: yaml

    neutron:
      compute:
        version: mitaka
        ...
        dvr: True
        agent_mode: dvr
        external_access: False
        backend:
          engine: ml2
          tenant_network_types: "flat,vlan" # Can be mixed flat,vlan,vxlan
          mechanism:
            ovs:
              driver: openvswitch

Advanced Neutron Features (DPDK, SR-IOV)
----------------------------------------

Neutron OVS DPDK

Enable datapath netdev for neutron openvswitch agent

.. code-block:: yaml

    neutron:
      server:
        version: mitaka
        ...
        dpdk: True
        ...

    neutron:
      compute:
        version: mitaka
        dpdk: True
        backend:
          engine: ml2
          ...
          mechanism:
            ovs:
              driver: openvswitch

Neutron OVS SR-IOV

.. code-block:: yaml

    neutron:
      server:
        version: mitaka
        backend:
          engine: ml2
          ...
          mechanism:
            ovs:
              driver: openvswitch
            sriov:
              driver: sriovnicswitch

    neutron:
      compute:
        version: mitaka
        ...
        backend:
          engine: ml2
          tenant_network_types: "flat,vlan" # Can be mixed flat,vlan,vxlan
          sriov:
            nic_one:
              devname: eth1
              physical_network: physnet3
          mechanism:
            ovs:
              driver: openvswitch

Neutron with VLAN-aware-VMs
---------------------------

.. code-block:: yaml

    neutron:
      server:
        vlan_aware_vms: true
      ....
      compute:
        vlan_aware_vms: true
      ....
      gateway:
        vlan_aware_vms: true

Neutron with OVN
----------------

Control node:

.. code-block:: yaml

    neutron:
      server:
        backend:
          engine: ovn
          mechanism:
            ovn:
              driver: ovn
          tenant_network_types: "geneve,flat"

Compute node:

.. code-block:: yaml

    neutron:
      compute:
        local_ip: 10.2.0.105
        controller_vip: 10.1.0.101
        external_access: false
        backend:
          engine: ovn

Neutron Server
--------------

Neutron Server with OpenContrail

.. code-block:: yaml

    neutron:
      server:
        backend:
          engine: contrail
          host: contrail_discovery_host
          port: 8082
          user: admin
          password: password
          tenant: admin
          token: token

Neutron Server with Midonet

.. code-block:: yaml

    neutron:
      server:
        backend:
          engine: midonet
          host: midonet_api_host
          port: 8181
          user: admin
          password: password

Neutron Keystone region

.. code-block:: yaml

    neutron:
      server:
        enabled: true
        version: kilo
        ...
        identity:
          region: RegionTwo
        ...
        compute:
          region: RegionTwo
        ...

Client-side RabbitMQ HA setup

.. code-block:: yaml

    neutron:
      server:
        ....
        message_queue:
          engine: rabbitmq
          members:
            - host: 10.0.16.1
            - host: 10.0.16.2
            - host: 10.0.16.3
          user: openstack
          password: pwd
          virtual_host: '/openstack'
        ....

Client-side RabbitMQ TLS configuration:

|

To enable TLS for oslo.messaging you need to provide the CA certificate.

By default system-wide CA certs are used. Nothing should be specified except `ssl.enabled`.

.. code-block:: yaml

  neutron:
    server, gateway, compute:
      ....
      message_queue:
        ssl:
          enabled: True



Use `cacert_file` option to specify the CA-cert file path explicitly:

.. code-block:: yaml

  neutron:
    server, gateway, compute:
      ....
      message_queue:
        ssl:
          enabled: True
          cacert_file: /etc/ssl/rabbitmq-ca.pem

To manage content of the `cacert_file` use the `cacert` option:

.. code-block:: yaml

  neutron:
    server, gateway, compute:
      ....
      message_queue:
        ssl:
          enabled: True
          cacert: |

          -----BEGIN CERTIFICATE-----
                    ...
          -----END CERTIFICATE-------

          cacert_file: /etc/openstack/rabbitmq-ca.pem


Notice:
 * The `message_queue.port` is set to **5671** (AMQPS) by default if `ssl.enabled=True`.
 * Use `message_queue.ssl.version` if you need to specify protocol version. By default is TLSv1 for python < 2.7.9 and TLSv1_2 for version above.


Enable auditing filter, ie: CADF

.. code-block:: yaml

    neutron:
      server:
        audit:
          enabled: true
      ....
          filter_factory: 'keystonemiddleware.audit:filter_factory'
          map_file: '/etc/pycadf/neutron_api_audit_map.conf'
      ....
      compute:
        audit:
          enabled: true
      ....
          filter_factory: 'keystonemiddleware.audit:filter_factory'
          map_file: '/etc/pycadf/neutron_api_audit_map.conf'
      ....

Neutron with security groups disabled

.. code-block:: yaml

    neutron:
      server:
        security_groups_enabled: False
      ....
      compute:
        security_groups_enabled: False
      ....
      gateway:
        security_groups_enabled: False


Neutron Client
--------------

Neutron networks

.. code-block:: yaml

    neutron:
      client:
        enabled: true
        server:
          identity:
            endpoint_type: internalURL
            network:
              inet1:
                tenant: demo
                shared: False
                admin_state_up: True
                router_external: True
                provider_physical_network: inet
                provider_network_type: flat
                provider_segmentation_id: 2
                subnet:
                  inet1-subnet1:
                    cidr: 192.168.90.0/24
                    enable_dhcp: False
              inet2:
                tenant: admin
                shared: False
                router_external: True
                provider_network_type: "vlan"
                subnet:
                  inet2-subnet1:
                    cidr: 192.168.92.0/24
                    enable_dhcp: False
                  inet2-subnet2:
                    cidr: 192.168.94.0/24
                    enable_dhcp: True
          identity1:
            network:
              ...

Neutron routers

.. code-block:: yaml

    neutron:
      client:
        enabled: true
        server:
          identity:
            endpoint_type: internalURL
            router:
              inet1-router:
                tenant: demo
                admin_state_up: True
                gateway_network: inet
                interfaces:
                  - inet1-subnet1
                  - inet1-subnet2
          identity1:
            router:
              ...

    TODO: implement adding new interfaces to a router while updating it


Neutron security groups

.. code-block:: yaml

    neutron:
      client:
        enabled: true
        server:
          identity:
            endpoint_type: internalURL
            security_group:
              security_group1:
                tenant: demo
                description: security group 1
                rules:
                  - direction: ingress
                    ethertype: IPv4
                    protocol: TCP
                    port_range_min: 1
                    port_range_max: 65535
                    remote_ip_prefix: 0.0.0.0/0
                  - direction: ingress
                    ethertype: IPv4
                    protocol: UDP
                    port_range_min: 1
                    port_range_max: 65535
                    remote_ip_prefix: 0.0.0.0/0
                  - direction: ingress
                    protocol: ICMP
                    remote_ip_prefix: 0.0.0.0/0
          identity1:
            security_group:
              ...

    TODO: implement updating existing security rules (now it adds new rule if trying to update existing one)


Floating IP addresses

.. code-block:: yaml

    neutron:
      client:
        enabled: true
        server:
          identity:
            endpoint_type: internalURL
            floating_ip:
              prx01-instance:
                server: prx01.mk22-lab-basic.local
                subnet: private-subnet1
                network: public-net1
                tenant: demo
              gtw01-instance:
                ...

.. note:: The network must have flag router:external set to True.
          Instance port in the stated subnet will be associated with the dynamically generated floating IP.



Enable Neutron extensions (QoS, DNS, etc.)
------------------------------------------
.. code-block:: yaml

    neutron:
      server:
        backend:
          extension:
            dns:
              enabled: True
              host: 127.0.0.1
              port: 9001
              protocol: http
              ....
            qos
              enabled: True



Neutron with Designate
-----------------------------------------
.. code-block:: yaml

    neutron:
      server:
        backend:
          extension:
            dns:
              enabled: True
              host: 127.0.0.1
              port: 9001
              protocol: http



Documentation and Bugs
======================

To learn how to install and update salt-formulas, consult the documentation
available online at:

    http://salt-formulas.readthedocs.io/

In the unfortunate event that bugs are discovered, they should be reported to
the appropriate issue tracker. Use Github issue tracker for specific salt
formula:

    https://github.com/salt-formulas/salt-formula-neutron/issues

For feature requests, bug reports or blueprints affecting entire ecosystem,
use Launchpad salt-formulas project:

    https://launchpad.net/salt-formulas

You can also join salt-formulas-users team and subscribe to mailing list:

    https://launchpad.net/~salt-formulas-users

Developers wishing to work on the salt-formulas projects should always base
their work on master branch and submit pull request against specific formula.

    https://github.com/salt-formulas/salt-formula-neutron

Any questions or feedback is always welcome so feel free to join our IRC
channel:

    #salt-formulas @ irc.freenode.net
