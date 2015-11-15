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


# Docker Multi-host Networking Introduction

Docker kicked out with a simple single-host networking from the very beginning. Unfortunately, this prevents Docker clusters from scale out to multiple hosts. A number of projects put their focus on this problem such as Calico, Flannel and Weave, and also since Nov. 2015, Docker support the Multi-host Overlay Networking itself.

What these projects have in common is trying to control the container's networking configurations, thus to capture and inject network packets. Consequently, every containers located on different hosts can get IPs in the same subnet and communicate with each other as if they are connected to the same L2 switch. In this way, containers could spread out on multiple hosts, even on multiple data centers.

While there are also a lot of differences between them from technical models, network topology and features. This post will mainly focus on the differences between Calico, Flannel, Weave and Docker Overlay Network, and you could choose the right solution which fits best to your requirements.


# Battlefield Overview

According the features these Big Four support, I will compare them in the following aspects:

* **Network Model** - What kind of network model are used to support multi-host network.
* **IPAM Support** - Support what kind of IP address management.
* **Name Service** - DNS lookup with simple hostname or DNS rules.
* **Application Isolation** - Support what level and kind of application isolation of containers.
* **Distributed Storage Requirements** - Whether an external distributed storage is required, e.g. etcd or consul.
* **Partially Connected Host Network Support** - Whether the system can run on a partially connected host network.
* **IP Overlap Support** - Whether the same IP can be allocated to different containers.

Now let's see more details of these aspects on Calico, Flannel, Weave and Docker Overlay Network.


# Network Model




















