title: Flannel for Docker Overlay Network
date: 2015-10-10 18:03:49
tags:
	- Docker
	- Multi-host Network
	- Flannel
categories:
	- Docker Multi-host Network
---

In previous post, some overlay network technologies for Docker are analysised. On this post let's focus on [Flannel](https://github.com/coreos/flannel), a virtual network that creates subnet work Dockers across different hosts.

# Introduction to Flannel

[Flannel](https://github.com/coreos/flannel), similar to [Calico](https://github.com/projectcalico/calico-docker), [VXLAN](https://datatracker.ietf.org/doc/rfc7348/) and [Weave](https://github.com/weaveworks/weave), provides a configurable virtual overlay network for Docker. Flannel runs an agent, flanneld, on each host and is responsible for allocating subnet lease out of a preconfigured address space. Flannel uses [etcd](https://github.com/coreos/etcd) to store network configurations. I copied this architecture image from [Flannel GitHub page](https://github.com/coreos/flannel) to illustrate the details of the path a packet take as it tranverse the overlay network.

{% img /images/flannel-01.png %}


# Config Etcd

## Download and Run Etcd

Since Flannel depends on Etcd, you need to download, run and config Etcd before starting flanneld. Assume that you have two Linux VM (or physical machine) with hostname node1/node2 and IP 192.168.236.130/131 seperately. On each node download and run Etcd as follows:

{% codeblock lang:bash Download and run etcd%}
curl -L  https://github.com/coreos/etcd/releases/download/v2.2.1/etcd-v2.2.1-linux-amd64.tar.gz -o etcd-v2.2.1-linux-amd64.tar.gz
tar xzvf etcd-v2.2.1-linux-amd64.tar.gz
cd etcd-v2.2.1-linux-amd64
./etcd -name {node} -initial-advertise-peer-urls http://0.0.0.0:2380 \
  -listen-peer-urls http://0.0.0.0:2380 \
  -listen-client-urls http://0.0.0.0:2379,http://127.0.0.1:4001 \
  -advertise-client-urls http://0.0.0.0:2379 \
  -initial-cluster-token etcd-cluster \
  -initial-cluster node1=http://192.168.236.130:2380,node2=http://192.168.236.131:2380 \
  -initial-cluster-state new
{% endcodeblock %}

## Config Etcd
Flannel reads its configuration from etcd. By default, it will read the configuration from `/coreos.com/network/config` (can be overridden via --etcd-prefix). You need to use `etcdctl` utility to set values in etcd. On the directory you downloaded Etcd previously, run following commands:

{% codeblock lang:bash Config Etcd %}
./etcdctl set /coreos.com/network/config 	\
	'{"Network": "10.0.0.0/8",				\
	"SubnetLen": 20,						\
	"SubnetMin": "10.10.0.0",				\
	"SubnetMax": "10.99.0.0",				\
	"Backend": {							\
		"Type": "udp",						\
		"Port": 7890}} '
{% endcodeblock %}


# Build and Run Flannel

## Build Flannel

* Step 1: On ubuntu, run `sudo apt-get install linux-libc-dev golang gcc`. On Fedora/Redhat, run `sudo yum install kernel-headers golang gcc`.
* Step 2: Git clone the flannel repo: git clone https://github.com/coreos/flannel.git
* Step 3: Run the build script: cd flannel; ./build

If Flannel build failed on your local environment, you can also build flannel inside a Docker container. Confirm that you have install Docker first with `docker -v`, and then execute:

{% codeblock lang:bash Install Docker %}
cd flannel
docker build .
{% endcodeblock %}


## Run Flannel

After Etcd is set up, you need to run flanneld on both nodes:

{% codeblock lang:bash Run flannel %}
sudo ./bin/flanneld &
{% endcodeblock %}

Use `ifconfig` to confirm the network of flanned was setup successfully, the outputs should be something like this:

	flannel0  Link encap:UNSPEC  HWaddr 00-00-00-00-00-00-00-00-00-00-00-00-00-00-00-00
	          inet addr:10.15.240.0  P-t-P:10.15.240.0  Mask:255.0.0.0
	          UP POINTOPOINT RUNNING NOARP MULTICAST  MTU:1472  Metric:1
	          RX packets:606921 errors:0 dropped:0 overruns:0 frame:0
	          TX packets:308311 errors:0 dropped:0 overruns:0 carrier:0
	          collisions:0 txqueuelen:500
	          RX bytes:893358516 (893.3 MB)  TX bytes:16225380 (16.2 MB)

After Flannel is running, you need to config network for docker0 and restart docker daemon with Flannel network configuration, execute commands as follows:

{% codeblock lang:bash Run flannel %}
service docker stop
source /run/flannel/subnet.env
sudo ifconfig docker0 ${FLANNEL_SUBNET}
sudo docker daemon --bip=${FLANNEL_SUBNET} --mtu=${FLANNEL_MTU} &
docker ps
{% endcodeblock %}

## Start Docker

After Flannel set up, just start your docker without any differences without Flannel. Run the following command on node1:

{% codeblock lang:bash Run Docker %}
sudo docker run -itd --name=worker-1 ubuntu
sudo docker run -itd --name=worker-2 ubuntu
{% endcodeblock %}

Then run Docker on node2:

{% codeblock lang:bash Run Docker %}
sudo docker run -itd --name=worker-3 ubuntu
{% endcodeblock %}

Then use `sudo docker exec worker-N ifconfig` to get the IP of these workers (e.g. 10.15.240.2, 10.15.240.3 and 10.10.160.2 for worker-1/2/3). On node1, test connectivity to worker-3:

{% codeblock lang:bash Test connectivity %}
sudo docker exec worker-1 ping -c4 10.10.160.2
sudo docker exec worker-1 ping www.google.com
{% endcodeblock %}

All these pings should return successfully.


# Simple Performance Test

Until now Flannel is setup for Docker and all the workers are connected with each other **physically**. Then I did a simple performance test with iperf between two Dockers in different/same hosts.

Firstly let's see the native network performance between two hosts:

	flannel@node2:~# iperf -c 192.168.236.130
	------------------------------------------------------------
	Client connecting to 192.168.236.130, TCP port 5001
	TCP window size: 85.0 KByte (default)
	------------------------------------------------------------
	[  3] local 192.168.236.131 port 54584 connected with 192.168.236.130 port 5001
	[ ID] Interval       Transfer     Bandwidth
	[  3]  0.0-10.0 sec  2.57 GBytes  2.21 Gbits/sec

Then dockers on different host:

	root@93c451432761:~# iperf -c 10.10.160.2
	------------------------------------------------------------
	Client connecting to 10.10.160.2, TCP port 5001
	TCP window size: 85.0 KByte (default)
	------------------------------------------------------------
	[  3] local 10.15.240.2 port 57496 connected with 10.10.160.2 port 5001
	[ ID] Interval       Transfer     Bandwidth
	[  3]  0.0-10.0 sec   418 MBytes   351 Mbits/sec

The performance of Dockers on the same host is pretty good.

	root@93c451432761:~# iperf -c 10.15.240.3
	------------------------------------------------------------
	Client connecting to 10.15.240.3, TCP port 5001
	TCP window size: 85.0 KByte (default)
	------------------------------------------------------------
	[  3] local 10.15.240.2 port 38099 connected with 10.15.240.3 port 5001
	[ ID] Interval       Transfer     Bandwidth
	[  3]  0.0-10.0 sec  39.2 GBytes  33.7 Gbits/sec

~~**The performace is so bad compared with native!!!!!** I can't figure out why the performance degrades too much with Flannel. Since Calico and Docker Multi-host Network can achieve more than 80% performance compared with native, Flannel does a aweful job apparently. If anyone knows why, please email me or comments under this blog.~~

After read through the configuration documents of Flannel, I found that flannel support two backends: UDP backend and VxLAN backend. Try VxLAN backend and the speed is much more fast and close to native performance.


# UDP and VxLAN backends

There are two different backends supported by Flannel. The previous configuration on this blog uses UDP backend, which is a pretty slow solution because all the packets are encrypted in userspace. VxLAN backend uses Linux Kernel VxLAN support as well as some hardware features to achieve a much more faster network.

It's easy to use VxLAN backend. When configuring Etcd, just define the `backend` block with `vxlan`.

{% codeblock lang:bash Config Etcd %}
./etcdctl set /coreos.com/network/config 	\
	'{"Network": "10.0.0.0/8",				\
	"SubnetLen": 20,						\
	"SubnetMin": "10.10.0.0",				\
	"SubnetMax": "10.99.0.0",				\
	"Backend": {							\
		"Type": "vxlan"}} '
{% endcodeblock %}

With VxLAN backend, the iperf result of two containers on different hosts are as follows:

	root@93c451432761:~# iperf -c 10.15.240.3
	------------------------------------------------------------
	Client connecting to 10.15.240.3, TCP port 5001
	TCP window size: 85.0 KByte (default)
	------------------------------------------------------------
	[  3] local 10.15.240.2 port 38099 connected with 10.15.240.3 port 5001
	[ ID] Interval       Transfer     Bandwidth
	[  3]  0.0-10.0 sec  1.80 GBytes  1.56 Gbits/sec

This is an acceptable result with about 80% performance compared with native network.

# References

[1] Flannel code base, [https://github.com/coreos/flannel](https://github.com/coreos/flannel)
[2] Using coreos flannel for docker networking, [http://www.slideshare.net/lorispack/using-coreos-flannel-for-docker-networking](http://www.slideshare.net/lorispack/using-coreos-flannel-for-docker-networking)



