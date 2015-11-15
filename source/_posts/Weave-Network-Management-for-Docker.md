title: 'Weave: Network Management for Docker'
date: 2015-11-14 19:38:28
tags:
	- Docker
	- Multi-host Network
	- Weave
categories:
	- Docker Multi-host Network
---

[Weave](https://github.com/weaveworks/weave) is developed by [Weaveworks](http://weave.works/) for developers to control and observe Docker containers network. Similar to [Flannel](/2015/10/10/Flannel-for-Docker-Overlay-Network/), [Calico](/2015/09/06/calico-docker/) and [Docker Overlay Network](/2015/11/09/docker-multi-host-networking/), Weave handles Docker multi-host networking and management which can merge network of Docker's laying on different hosts. Compared with the rest three solutions, weave provides more features and choices. I will write another blog to compare these four solutions in details. In this blog, I will focus on Weave's install, features and technology inside.


# About Weave

Weave creates a virtual network that connects Dockers deployed across multiple hosts as well as their DNS discovery. Dockers on different hosts can communicate with each other just the same as they are in the same LAN, and broadcast is also well supported in such LAN network. Besides Dockers can discover each other by hostname implemented by Weave DNS discovery module, which is not supported by other multi-host network solutions.

Weave can also tranverse the firewall and operate in partially connected networks. Packets will tranvers via a shortest path to the destination host contains Docker, even though the host hides behind a firewall and the sender host cannot access destination host directly. Traffic can also be encrypted, allowing hosts connect each other via untrusted network.

Weave cooperates with Docker current single host or overlay network also, so there would be a seperate NIC for weave in Docker, as well as a weave virtual NIC on the host to capture all the packets send from Dockers.


# Installation and Configuration

## Prerequsites

Two or more hosts (VM or PM) are need to setup a Docker cluster via weave. Here I use two Ubuntu 15.10 VM located on VMs running on my Mac. Let's name these two hosts node1 and node2 with IP 10.156.75.101 and 10.156.75.102 seperately. Please ensure you are running Linux (Kernel 3.8 or later) and have Docker (version 1.3.1 or later) installed. `curl` or any alternative software (e.g. wget) is also necessary to download weave binary file.


## Installation and Run Weave Cluster

Then run such commands to finish weave installation:

{% codeblock lang:bash Install weave %}
sudo curl -L git.io/weave -o /usr/local/bin/weave
sudo chmod a+x /usr/local/bin/weave
{% endcodeblock %}

Thus weave is installed succesfully. It's so easy, right? The most important part for weave is not the binary itself. When weave starts, two Dockers `weaveworks/weaveexec` and `weaveworks/weave` will run to handle all the network configurations and network discovery service.

Run on node1 to start weave service:

{% codeblock lang:bash %}
	root@node1:~# weave launch
	root@node1:~# docker ps
	CONTAINER ID        IMAGE                        COMMAND                  CREATED             STATUS              PORTS               NAMES
	81799b4eff2e        weaveworks/weaveexec:1.2.1   "/home/weave/weavepro"   28 seconds ago      Up 28 seconds                           weaveproxy
	676b4d58ead4        weaveworks/weave:1.2.1       "/home/weave/weaver -"   29 seconds ago      Up 29 seconds                           weave
{% endcodeblock %}

You can see two weave Dockers here. Then on node2, launch weave with it's partener node1 (10.156.75.102):

{% codeblock lang:bash %}
	root@node2:~# weave launch 10.156.75.101
{% endcodeblock %}

To confirm that weave cluster starts sucessfully, run following command on node1:

{% codeblock lang:bash %}
	root@node1:~# weave status connections
	<- 10.156.75.102:32854   established fastdp 66:b4:a1:85:da:65(node2)
{% endcodeblock %}

Now you sucessfully setup a weave connection between node1 and node2.


## Run Docker and Test Network

After weave cluster started, you could run Docker on node1 and node2 

{% codeblock lang:bash %}
	root@node1:~# weave run -itd --name=w1 ubuntu
	root@node2:~# weave run -itd --name=w2 ubuntu
{% endcodeblock %}

Then these two Dockers can communicate with each other. Test with a simple `ping`:

{% codeblock lang:bash %}
	root@node1:~# docker exec w1 ping -c4 w2
{% endcodeblock %}


# Simple Speed Test

After setting up Weave network, I use `perf` to perform a simple performance test between Dockers on same/different hosts and compare them with native network performance.

Here is the native performance between two hosts:

{% codeblock lang:bash %}
	root@node1:~# iperf -c node2
	------------------------------------------------------------
	Client connecting to node2, TCP port 5001
	TCP window size: 85.0 KByte (default)
	------------------------------------------------------------
	[  3] local 10.156.75.101 port 50534 connected with 10.156.75.102 port 5001
	[ ID] Interval       Transfer     Bandwidth
	[  3]  0.0-10.0 sec  2.57 GBytes  2.21 Gbits/sec
{% endcodeblock %}

And the performance between Dockers on different hosts:

{% codeblock lang:bash %}
	root@w3:/# iperf -c w1
	------------------------------------------------------------
	Client connecting to w1, TCP port 5001
	TCP window size: 76.5 KByte (default)
	------------------------------------------------------------
	[  3] local 10.2.1.65 port 43966 connected with 10.2.1.2 port 5001
	[ ID] Interval       Transfer     Bandwidth
	[  3]  0.0-10.0 sec  1.87 GBytes  1.61 Gbits/sec
{% endcodeblock %}

The performance between Dockers on the same host:

{% codeblock lang:bash %}
	root@a1:/# iperf -c w1
	------------------------------------------------------------
	Client connecting to w1, TCP port 5001
	TCP window size: 45.0 KByte (default)
	------------------------------------------------------------
	[  3] local 10.2.1.1 port 33750 connected with 10.2.1.2 port 5001
	[ ID] Interval       Transfer     Bandwidth
	[  3]  0.0-10.2 sec  54.0 GBytes  46.3 Gbits/sec
{% endcodeblock %}

You can see network between Dockers on the same host is quite faster, the reason is Weave use `pcap` to identify whether the packet's destination is located on the same host or not. Thus for the communications of Dockers on the same host, Weave could directly forward the packets to the right destination.

This is only a simple performance test. I will perform a detailed test in the following blog with the comparison of Weave, Calico, Flannel, Docker Overlay Netowrk.


# Dive Deep into Weave

## Weave Network Topology

The main difference between Weave and other Docker multi-host network solutions is that Weave network uses a number `peers` to perform as the routers residing on different hosts. These routers build a network of these hosts and sends or routes packets to the right destination. Each peer has a human friendly nickname and a unique identifier which is different on its each run.

Weave routers establish TCP connections to each other to perform starting handshakes and topology exchange on the runtime. Peers also establish UDP tunnels to carry encapsulate network packets. These packets can tranverse firewall with the help of other routers.

Weave creates a network bridge on each host, and each container is connected to this bridge. After you start a Docker with Weave network, you could find the created bridge via `ifconfig`.

{% codeblock lang:bash %}
	root@node1:~# ifconfig
	...
	weave     Link encap:Ethernet  HWaddr 4a:15:49:23:bf:9c
	          inet6 addr: fe80::4815:49ff:fe23:bf9c/64 Scope:Link
	          UP BROADCAST RUNNING MULTICAST  MTU:1410  Metric:1
	          RX packets:726 errors:0 dropped:0 overruns:0 frame:0
	          TX packets:8 errors:0 dropped:0 overruns:0 carrier:0
	          collisions:0 txqueuelen:0
	          RX bytes:33956 (33.9 KB)  TX bytes:648 (648.0 B)
	...
{% endcodeblock %}

This bridge performs the packets forwarding to and from the Dockers. Besides, Dockers connected to this bridge also creates a veth NIC. The container side veth is given an IP address and netmask by Weave's IPAM module. The Weave router captures Ethernet packets from the bridged interface using `pcap` feature. This typically bypass packets tranversing between local containers, which will gain a better local containers networking performance. For packets between different hosts, Weave router will choose a best routing and send the packet to the next hop.


## Partially Connected Network Support

Differ from other solutions, Weave doesn't rely on distributed storage (e.g. etcd and consul) to exchange routing information. Weave peers build a routing network themselves and implement rumour protocol to exchange networking topology when new peer adds and exits. Weave can also perform on a partially connected network and exchange packets with the help of other peers. Given a partially connected network as follows:

{% img /images/wave-topology.png %}

Peer 1/2/3 are connected to each other while peer 4 only connects to peer 3. If containers on peer 1 want to talk to containers on peer 4, the packets will first be send to peer 3 and then to peer 4. The connections between two directly connected host could achieve a `fastdp` connection and the indirect connections can only use `sleeve` connection. These two different connections have a huge gap in speed. I run a simple test with `iperf` on three containers, `w1` & `w2` and `w1` & `w3` locate on the directly connected hosts but `w2` & `w3` locate on the indirectly connected hosts. From the indirectly connected host `node-pub-1`, you could run `weave status connections` to retrieve the connections:

{% codeblock lang:bash %}
	root@node-pub-1:~# weave status connections
	-> 10.156.75.102:6783    established sleeve 66:b4:a1:85:da:65(node2)
	-> 192.168.70.201:6783   established fastdp 4a:15:49:23:bf:9c(node1)
{% endcodeblock %}

Then speed test results are as follows:

{% codeblock lang:bash %}
	root@w3:/# iperf -c w2
	------------------------------------------------------------
	Client connecting to w2, TCP port 5001
	TCP window size: 45.0 KByte (default)
	------------------------------------------------------------
	[  3] local 10.2.1.65 port 54304 connected with 10.2.1.129 port 5001
	[ ID] Interval       Transfer     Bandwidth
	[  3]  0.0-10.0 sec   146 MBytes   123 Mbits/sec

	root@w3:/# iperf -c w1
	------------------------------------------------------------
	Client connecting to w1, TCP port 5001
	TCP window size: 76.5 KByte (default)
	------------------------------------------------------------
	[  3] local 10.2.1.65 port 43966 connected with 10.2.1.2 port 5001
	[ ID] Interval       Transfer     Bandwidth
	[  3]  0.0-10.0 sec  1.77 GBytes  1.52 Gbits/sec
{% endcodeblock %}

We could see the directly connected w1 and w3 achieve a quite high performance of 1.52 Gbits/sec, which indirectly connected w2 and w3 only get about 10% bandwidth. This could be a bottlenet for Weave developers to overcome.


## Cooperate with Docker Control API

Weave provides a Docker API proxy to control weave docker in the same way of control Docker instead of using `weave run`. This allows you using the ordinary Docker [command-line interface](https://docs.docker.com/reference/commandline/cli/) or [remote API](https://docs.docker.com/reference/api/docker_remote_api/) to CRUD Dockers with Weave network.

In the previous chapters, we use `weave launch` to run Weave directly, and we could see Weave-related Dockers created on the host:

{% codeblock lang:bash %}
root@node1:~# docker ps
CONTAINER ID        IMAGE                        COMMAND                  CREATED             STATUS              PORTS               NAMES
ccb596b5a13a        weaveworks/weaveexec:1.2.1   "/home/weave/weavepro"   16 seconds ago      Up 16 seconds       weaveproxy
790cc66660fd        weaveworks/weave:1.2.1       "/home/weave/weaver -"   15 hours ago        Up 15 hours         weave
{% endcodeblock %}

For these two Weave services, `weave` perform the main functions for Weave network, such as network configuration and DNS lookup. `weaveproxy` performs the role of a proxy between Docker client (command line or API) and the Docker daemon, intercepting the communication between these two components.

Actually, `weave launch` performs `weave launch-router` and `weave launch-proxy` in a batch, you could run `weave launch-router` and `weave launch-proxy` seperately with different parameters. For example, if you want to control Weave via a TCP port instead of a unix file socket, you just need to add `-H` parameter to `weave launch-proxy`. You can run `weave stop-proxy` if you already use `weave launch` to launch both `router` and `proxy`.

{% codeblock lang:bash %}
root@node1:~# weave stop-proxy
root@node1:~# weave launch-proxy -H tcp://0.0.0.0:9999
root@node1:~# weave env
export DOCKER_HOST=tcp://127.0.0.1:9999 ORIG_DOCKER_HOST=
{% endcodeblock %}

From `weave env`, you can see the current intercepted DOCKER_HOST from Weave is `tcp://127.0.0.1:9999`, you can use `docker -H 127.0.0.1:9999 <command>` to control Docker with Weave network support.

You can also use following commands to add `tcp://127.0.0.1:9999` to `DOCKER_HOST` env params, thus you could use `docker` directly without assigning the API address.

{% codeblock lang:bash %}
root@node1:~# eval $(weave env)
{% endcodeblock %}

For more details about weave proxy, you can see the [official weave proxy documentation page](http://docs.weave.works/weave/latest_release/proxy.html).


## IP Allocation Strategy & Application Isolation

Some more parameters can be set when launching weave to make IP allocation more flexible, thus could achieve application isolation via the CIDR network isolation speculations. From `weave help` you can see more detailed parameters for weave launch. The bad things is that there's no more details on these params than listing them directly. But from the name of these params, you could guess what they are figuring out:

{% codeblock lang:bash %}
root@node1:~# weave help
Usage:
...
weave launch        [--password <password>] [--nickname <nickname>]
                      [--ipalloc-range <cidr> [--ipalloc-default-subnet <cidr>]]
                      [--no-discovery] [--init-peer-count <count>] <peer> ...
...
{% endcodeblock %}

For these params:
* `--password` : password for weave cluster, newer weave node must use this password to join
* `--nickname` : alias of weave node instead of its hostname
* `--ipalloc-range` : IP range allocated for Docker
* `--ipalloc-default-subnet` : default subnet allocated for Docker, you can use `-e WEAVE_CIDR=net:${CIDR}` when running a docker with other IP allocation method. See next chapter for more details.
* `--no-discovery` : don't use DNS discovery service
* `--init-peer-count <count>` : start service after `<count>` peers connect to the cluster

So if you want more flexible IP allocation methods, run the following commands on node1 and node2:

{% codeblock lang:bash %}
root@node1:~# weave launch --ipalloc-range 10.2.0.0/16 --ipalloc-default-subnet 10.2.1.0/24
root@node1:~# eval $(weave env)
{% endcodeblock %}

{% codeblock lang:bash %}
root@node2:~# weave launch --ipalloc-range 10.2.0.0/16 --ipalloc-default-subnet 10.2.1.0/24 $node1
root@node2:~# eval $(weave env)
{% endcodeblock %}

This delegates the entire 10.2.0.0/16 subnet to weave, and instructs it to allocate from 10.2.1.0/24 within that if no specific subnet is specified. Now we can launch some containers in the default subnet:

{% codeblock lang:bash %}
	root@node1:~# docker run --name a1 -ti ubuntu
	root@node2:~# docker run --name a2 -ti ubuntu
{% endcodeblock %}

And some more containers in a different subnet:

{% codeblock lang:bash %}
	root@node1:~# docker run -e WEAVE_CIDR=net:10.2.2.0/24 --name b1 -ti ubuntu
	root@node2:~# docker run -e WEAVE_CIDR=net:10.2.2.0.24 --name b2 -ti ubuntu
{% endcodeblock %}

A quick `ping` test could illustrates network connections betwwen a1~a2 and b1~b2:

{% codeblock lang:bash %}
	root@node1:~# docker exec a1 ping -c 4 a2
	root@node1:~# docker exec b1 ping -c 4 b2
{% endcodeblock %}

While no connections between a1~b2 or b1~a2:

{% codeblock lang:bash %}
	root@node1:~# docker exec a1 ping -c 4 b2
	root@node1:~# docker exec b1 ping -c 4 a2
{% endcodeblock %}


# Conclusion

Weave is a good networking management tools for Docker and provides the most functions compared with other solutions. You could find more feature details on its [official feature document](http://docs.weave.works/weave/latest_release/features.html).


# References
[1] Weaveworks homepage, http://weave.works/
[2] Weave GitHub homepage, https://github.com/weaveworks/weave
[3] Weave features, http://docs.weave.works/weave/latest_release/features.html
[4] Weave proxy reference, http://docs.weave.works/weave/latest_release/proxy.html


