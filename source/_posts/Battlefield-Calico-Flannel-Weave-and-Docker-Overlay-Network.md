title: 'Battlefield: Calico, Flannel, Weave and Docker Overlay Network'
date: 2015-11-15 14:10:17
tags:
	- Docker
	- Multi-host Network
	- Calico
	- Flannel
	- Weave
	- Overlay Network
categories:
	- Docker Multi-host Network
---

From the previous posts, I have analysed 4 different Docker multi-host network solutions - Calico, Flannel, Weave and Docker Overlay Network. You can see more details on how to install, config and tune features of them from previous posts:

* [Calico: A Solution of Multi-host Network For Docker](/2015/09/06/calico-docker/)
* [Flannel for Docker Overlay Network](/2015/10/10/Flannel-for-Docker-Overlay-Network/)
* [Weave: Network Management for Docker](/2015/11/14/Weave-Network-Management-for-Docker/)
* [Docker Multi-host Overlay Networking with Etcd](/2015/11/09/docker-multi-host-networking/)

This post provides a battlefiled for these 4 Docker multi-host network solutions, including features and performances.

**If you want to see the results directly, directly jump to the [Conclusion](/2015/11/15/Battlefield-Calico-Flannel-Weave-and-Docker-Overlay-Network/#Conclusion) chapter.**


# Docker Multi-host Networking Introduction

Docker kicked out with a simple single-host networking from the very beginning. Unfortunately, this prevents Docker clusters from scale out to multiple hosts. A number of projects put their focus on this problem such as Calico, Flannel and Weave, and also since Nov. 2015, Docker support the Multi-host Overlay Networking itself.

What these projects have in common is trying to control the container's networking configurations, thus to capture and inject network packets. Consequently, every containers located on different hosts can get IPs in the same subnet and communicate with each other as if they are connected to the same L2 switch. In this way, containers could spread out on multiple hosts, even on multiple data centers.

While there are also a lot of differences between them from technical models, network topology and features. This post will mainly focus on the differences between Calico, Flannel, Weave and Docker Overlay Network, and you could choose the right solution which fits best to your requirements.


# Battlefield Overview

According the features these Big Four support, I will compare them in the following aspects:

* **Network Model** - What kind of network model are used to support multi-host network.
* **Application Isolation** - Support what level and kind of application isolation of containers.
* **Name Service** - DNS lookup with simple hostname or DNS rules.
* **Distributed Storage Requirements** - Whether an external distributed storage is required, e.g. etcd or consul.
* **Encryption Channel** - Whether data and infomation tranvers can put in an encryption channel.
* **Partially Connected Network Support** - Whether the system can run on a partially connected host network.
* **Seperate vNIC for Container** - Whether a seperate NIC is generated for container.
* **IP Overlap Support** - Whether the same IP can be allocated to different containers.
* **Container Subnet Restriction** - Whether container's subnet should not be the same as host's.
* **Protocol Support** - What kind of Layer-3 or Layer-4 protocols are supported.

Now let's see more details of these aspects on Calico, Flannel, Weave and Docker Overlay Network.


# Network Model

Multi-host networking means aggregating containers on different hosts to a same virtual network, and also these networking providers (Calico, etc.) are organized as a clustering network, too. The cluster organizations are called network model in this post. Technically, these four solutions uses different network model to organize their own network topology.

**Calico** implements a pure Layer 3 approach to achieve a simpler, higher scaling, better performance and more efficient multi-host networking. So Calico can not be treated as an `overlay network`. The pure Layer 3 approach avoids the packet encapsulation associated with the Layer 2 solution which simplifies diagnostics, reduces transport overhead and improves performance. Calico also implements BGP protocl for routing combined with a pure IP network, thus allows Internetl scaling for virtual networks.

**Flannel** has two different network model to choose. One is called UDP backend, which is a simple IP-over-IP solutions which uses a TUN device to encapsulate every IP fragment in a UDP packet, thus forming an overlay network; the other is a VxLAN backend, which is same as Docker Overlay Network. I have run a simple test for these two models, VxLAN is much more faster than UDP backend. The reason, I suggest, is that VxLAN is well supported by Linux Kernel, while UDP backend implements a pure software-layer encapsulation. Flannel requires a Etcd cluster to store the network configuration, allocate subnets and auxiliary data (such as host's IP). And the packet routing also requires the cooperation of Etcd cluster. Besides, Flannel runs a seperate process `flanneld` on host environment to support packet switching. Apart from Docker, flannel can also used for traditional VMs.

**Weave** also has two different connection modes. One is called `sleeve`, which implements a UDP channel to tranverse IP packets from containers. The main differences between Weave sleeve mode and Flannel UDP backend mode is that, Weave will merge multiple container's packet to one packet and transfer via UDP channel, so technically Weave sleeve mode will be a bit faster than Flannel UDP backend mode in most cases. The other connection mode of Weave is called `fastdp` mode, which also implements a VxLAN solutions. Though there's no official documents clarifying the VxLAN usage, we still can found the usage of VxLAN from Weave codes. Weave runs a Docker container performing the same role as `flanneld`.

**Docker Overlay Network** implements a VxLAN-based solution with the help of `libnetwork` and `libkv`, and, of course, is integrated into Docker succesfully without any seperate process or containers.

So a brief conclusion of network model is in the following table:

|               | Calico                | Flannel              | Weave                | Docker Overlay Network |
| ------------- |-----------------------|----------------------|----------------------|------------------------|
| Network Model | Pure Layer-3 Solution | VxLAN or UDP Channel | VxLAN or UDP Channel | VxLAN                  |


# Application Isolation

Since containers are connected to each other, we need a method to put containers into different groups and isolate containers in different group.


**Flannel**, **Weave** and **Docker Overlay Network** uses the same application isolation schema - the traditional CIDR isolation. The traditional CIDR isolation uses netmask to identify different subnet, and machines in different subnet cannot talk to each other. For example, w1/w2/w3 has IP 192.168.0.2/24 192.168.0.3/24 and 192.168.1.2/24 seperately. w1 and w2 can talk to each other since they are in the same subnet 192.168.0.0/24, but w3 cannot talk to w1 and w2.

**Calico** implements another type of application isolation schema - profile. You can create a batch of profiles and append containers with Calico network into different profiles. Only containers in the same profile could talk to each other. Containers in differen profile cannot access to each other even though they are in the same CIDR subnet.

**Brief conclusion:**

|                       | Calico         | Flannel           | Weave            | Docker Overlay Network |
| --------------------- |----------------|-------------------|------------------|------------------------|
| Application Isolation | Profile Schema | CIDR Schema       | CIDR Schema      | CIDR Schema            |


# Protocol Support

Since **Calico** is a pure Layer-3 solution, not all Layer-3 or Layer-4 protocols are supported. From the official github forum, developers of Calico declaims only **TCP**, **UDP**, **ICMP** ad **ICMPv6** are supported by Calico. It does make sense that supporting other protocols are a bit harder in such a Layer-3 solution.

Other solutions support all protocols. It's easy for them to achieve so because either udp encapsulation or VxLAN can support encapsulate L2 packets over L3. So it doesn't matter what kind of protocol the packet holds.

**Brief conclusion:**

|                    | Calico                  | Flannel           | Weave           | Docker Overlay Network |
| ------------------ |-------------------------|-------------------|-----------------|------------------------|
| Protocol Support   | TCP, UDP, ICMP & ICMPv6 | ALL               | ALL             | ALL                    |



# Name Service

**Weave** supports a name service between containers. When you create a container, Weave will put it into a DNS name service with format {hostname}.weave.local. Thus you can access to any container with {hostname}.weave.local or simply use {hostname}. The suffix (weave.local) can be changed to other strings, and the DNS lookup service can also be turned off.

The others don't have such feature.

**Brief conclusion:**

|                       | Calico         | Flannel           | Weave            | Docker Overlay Network |
| --------------------- |----------------|-------------------|------------------|------------------------|
| Name Service          | No             | No                | Yes              | No                     |


# Distributed Storage Requirements

As to **Calico**, **Flannel** and **Docker Overlay Network**, a distributed storage such as Etcd and Consul is a requirement to change routing and host information. Docker Overlay Network can also cooperate with Docker Swarm's discovery services to build a cluster.

**Weave**, however, doesn't need a distributed storage because Weave itself has a node discovery service using Rumor Protocol. This design decouples with another distributed storage system while introduces complexity and consistency concern of IP allocations, as well as the IPAM performance when cluster grows larger.

**Brief conclusion:**

|                                  | Calico         | Flannel           | Weave            | Docker Overlay Network |
| -------------------------------- |----------------|-------------------|------------------|------------------------|
| Distributed Storage Requirements | Yes            | Yes               | No               | Yes                    |


# Encryption Channel

**Flannel** supports TLS encryption channel between Flannel and Etcd, as well as data path between Flannel peers. You can see more details on `flanneld --help` with `-etcd-certfile` and `-remote-certfile` parameters.

**Weave** can be configured to encrypt both control data passing over TCP connections and the payloads of UDP packets sent between peers. This is accomplished with the [NaCl](http://nacl.cr.yp.to/) crypto libraries employing Curve25519, XSalsa20 and Poly1305 to encrypt and authenticate messages. Weave protects against injection and replay attacks for traffic forwarded between peers.

**Calico** and **Docker Overlay Network** doesn't support any kinds of encryption method, neither Calico-Etcd channel nor data path between Calico peers. But Calico achieves best performance among these four solutions, so it's better fit for an internal environment or if you don't care about data safety.

**Brief conclusion:**

|                         | Calico         | Flannel           | Weave            | Docker Overlay Network |
| ----------------------- |----------------|-------------------|------------------|------------------------|
| Encryption Channel      | No             | TLS               | NaCl Library     | No                     |


# Partially Connected Network Support

**Weave** can be deployed in a partially connected network, a brief example is as follows:

{% img /images/wave-topology.png %}

There are four peers with peer 1~3 connect with each other and peer 4 only connects to peer3. Weave can be deployed on peer 1~4. Any traffic from containers on peer 1 to containers on peer 4 will be traversed via peer 3.

This feature allows Weave connects hosts aparted by a firewall, thus connects hosts with internal IP address in different data centers.

Others don't have such feature.

**Brief conclusion:**

|                                     | Calico         | Flannel           | Weave           | Docker Overlay Network |
| ----------------------------------- |----------------|-------------------|-----------------|------------------------|
| Partially Connected Network Support | No             | No                | Yes             | No                     |


# Seperate vNIC for Container

Since **Flannel**, **Weave** and **Docker Overlay Network** create a bridged device and a veth inner containers, they create a seperate vNIC for containers. Routing table of container is also changed, thus bypass all packets of clustered network to this newly created NIC. Other connections, such as google.com, will route to the original vNIC.

**Calico** can use a unified vNIC for container because it's a pure Layer-3 solution. Calico can configure NAT for out-going requests and forward subnet packages to other Calico peers. Calico can also use Docker bridged NIC for out-going requests with some manual configuration inner containers. In this way, you need to add `-cap-add=Net_Admin` parameter when execute `docker run`.

**Brief conclusion:**

|                             | Calico         | Flannel           | Weave           | Docker Overlay Network |
| --------------------------- |----------------|-------------------|-----------------|------------------------|
| Seperate vNIC for Container | No             | Yes               | Yes             | yes                    |


# IP Overlap Support

Technically, for VxLAN-based solutions, tenant networks can have overlapping internal IP address, though IP addresses assigned to hosts must be unique. According to VxLAN speculations, **Weave**, **Flannel** and **Docker Overlay Network** can support IP overlap for containers. But on my testing environment, I cannot configure any of these three support IP overlap. So I can only say they have **potential** to support IP overlap.

**Calico** cannot support IP overlap technically, but Calico official documents emphasize that they can put overlapping IPv4 containers' packets on IPv6 network. Although this is an alternative solution for IPv4 network, I prefer to treate Calico not support IP overlap.

**Brief conclusion:**

|                    | Calico         | Flannel           | Weave           | Docker Overlay Network |
| ------------------ |----------------|-------------------|-----------------|------------------------|
| IP Overlap Support | No             | Maybe             | Maybe           | Maybe                  |


# Container Subnet Restriction

This section focus on whether container subnet can overlap with host network.

**Flannel** creates a real bridged network on the host with the subnet address, and use host Linux routing table to forward container packages to this bridge device. So container's subnet of Flannel cannot be overlap with host network, or host's routing table will be confused.

**Calico** is a pure Layer-3 implementation and packets from container to outter world will tranverse NAT table. So Calico also has such restriction that container subnet cannot overlap with host network.

**Weave** doesn't use host routing table to differentiate packages from containers, but use the `pcap` feature to deliver packages to the right place. So Weave doesn't need to obey the subnet restriction and it's free to allocate container a same IP address as host. Besides you can also change IP configurations inner container and the container could be reached by the new IP.

**Docker Overlay Network** allows container and host in the same subnet and achieve the isolation between them. But Docker Overlay Network rely on etcd to record routing information, so changing container's IP address manually will mess the routing process can lead container beyond reach.

**Brief conclusion:**

|                              | Calico         | Flannel           | Weave                         | Docker Overlay Network                  |
| ---------------------------- |----------------|-------------------|-------------------------------|-------------------------------------------|
| Container Subnet Restriction | No             | No                | Yes, configurable after start | Yes, not configurable after start |



# Conclusion

So let's give a final conclusion of all the aspects into one table. This table is one of the best references for you to choose a right multi-host networking solution.

|               | Calico                | Flannel              | Weave                | Docker Overlay Network |
| ------------- |-----------------------|----------------------|----------------------|------------------------|
| Network Model | Pure Layer-3 Solution | VxLAN or UDP Channel | VxLAN or UDP Channel | VxLAN                  |
| Application Isolation | Profile Schema | CIDR Schema       | CIDR Schema      | CIDR Schema            |
| Protocol Support   | TCP, UDP, ICMP & ICMPv6 | ALL               | ALL             | ALL                    |
| Name Service          | No             | No                | Yes              | No                     |
| Distributed Storage Requirements | Yes            | Yes               | No               | Yes                    |
| Encryption Channel      | No             | TLS               | NaCl Library     | No                     |
| Partially Connected Network Support | No             | No                | Yes             | No                     |
| Seperate vNIC for Container | No             | Yes               | Yes             | yes                    |
| IP Overlap Support | No             | Maybe             | Maybe           | Maybe                  |
| Container Subnet Restriction | No             | No                | Yes, configurable after start | Yes, not configurable after start |


My future plan is to test the performance of these four multi-host network solutions. Since there are too many contents on this post, I will create a new post to show the details of performance test.



