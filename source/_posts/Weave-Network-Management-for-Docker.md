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

Two or more hosts (VM or PM) are need to setup a Docker cluster via weave. Here I use two Ubuntu 15.10 VM located on VMware vCD cluster. Let's name these two hosts node1 and node2 with IP 10.156.75.101 and 10.156.75.102 seperately. Please ensure you are running Linux (Kernel 3.8 or later) and have Docker (version 1.3.1 or later) installed. `curl` or any alternative software (e.g. wget) is also necessary to download weave binary file.


## Installation and Run Weave Cluster

Then run such commands to finish weave installation:

{% codeblock lang:bash Install weave %}
sudo curl -L git.io/weave -o /usr/local/bin/weave
sudo chmod a+x /usr/local/bin/weave
{% endcodeblock %}

Thus weave is installed succesfully. It's so easy, right? The most important part for weave is not the binary itself. When weave starts, two Dockers `weaveworks/weaveexec` and `weaveworks/weave` will run to handle all the network configurations and network discovery service.

Run on node1 to start weave service:

	root@node1:~# weave launch
	root@node1:~# docker ps
	CONTAINER ID        IMAGE                        COMMAND                  CREATED             STATUS              PORTS               NAMES
	81799b4eff2e        weaveworks/weaveexec:1.2.1   "/home/weave/weavepro"   28 seconds ago      Up 28 seconds                           weaveproxy
	676b4d58ead4        weaveworks/weave:1.2.1       "/home/weave/weaver -"   29 seconds ago      Up 29 seconds                           weave

You can see two weave Dockers here. Then on node2, launch weave with it's partener node1 (10.156.75.102):

	root@node2:~# weave launch 10.156.75.101

To confirm that weave cluster starts sucessfully, run following command on node1:

	root@node1:~# weave status connections
	<- 10.156.75.102:32854   established fastdp 66:b4:a1:85:da:65(node2)

Now you sucessfully setup a weave connection between node1 and node2.


## Run Docker and Test Network

After weave cluster started, you could run Docker on node1 and node2 

	root@node1:~# docker run -itd --name=w1 ubuntu
	root@node2:~# docker run -itd --name=w2 ubuntu

Then these two Dockers can communicate with each other. Test with a simple `ping`:

	root@node1:~# docker exec w1 ping -c4 w2


# Flexible IP Allocation Strategy

Some more parameters can be set when launching weave to make IP allocation more flexible and achieve application isolation. From `weave help` you can see more detailed parameters for weave launch. The bad things is that there's no more details on these params than listing them directly. But from the name of these params, you could guess what they are figuring out:

{% codeblock %}
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

{% codeblock %}
root@node1:~# weave launch --ipalloc-range 10.2.0.0/16 --ipalloc-default-subnet 10.2.1.0/24
root@node1:~# eval $(weave env)
{% endcodeblock %}

{% codeblock %}
root@node2:~# weave launch --ipalloc-range 10.2.0.0/16 --ipalloc-default-subnet 10.2.1.0/24 $node1
root@node2:~# eval $(weave env)
{% endcodeblock %}

This delegates the entire 10.2.0.0/16 subnet to weave, and instructs it to allocate from 10.2.1.0/24 within that if no specific subnet is specified. Now we can launch some containers in the default subnet:

	root@node1:~# docker run --name a1 -ti ubuntu
	root@node2:~# docker run --name a2 -ti ubuntu

And some more containers in a different subnet:

	root@node1:~# docker run -e WEAVE_CIDR=net:10.2.2.0/24 --name b1 -ti ubuntu
	root@node2:~# docker run -e WEAVE_CIDR=net:10.2.2.0.24 --name b2 -ti ubuntu

A quick `ping` test could illustrates network connections betwwen a1~a2 and b1~b2:

	root@node1:~# docker exec a1 ping -c 4 a2
	root@node1:~# docker exec b1 ping -c 4 b2

While no connections between a1~b2 or b1~a2:

	root@node1:~# docker exec a1 ping -c 4 b2
	root@node1:~# docker exec b1 ping -c 4 a2


# Design

TBC

# Features

TBC









