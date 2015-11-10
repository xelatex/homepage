title: Setup PPTP Server on a VPS
date: 2015-05-20 14:45:45
tags:
  - PPTP
  - VPN
  - VPS
categories:
  - Fire on the Wall
---
VPS is becoming more and more cheap, fast and powerful these years. Some cheap VPS, such as Linode, Ramnode, DigitalOcean, DirectSpace, are provided for individuals. There are a lot of comparison article across the Internet and you can chose the one fit for you. Here I will list a bunch of methods to surf the internet across a firewall, and also some using experiments.


# Traditional VPN solutions

The traditional VPN solutions includes PPTP and L2TP+IPSec solutions. Both are the most popular VPN solutions which are support by almost any smart devices. PPTP and L2TP are all TCP-based VPN, which means a TCP connection must be contained between both ends to keep the status of VPN connection. Thus data lose or connection interrupted on these TCP connections will terminate the VPN connection. Besides these two VPNs are unable to change their TCP connection ports, that’s why PPTP and L2TP are easy to detect and blocked by the firewall. PPTP consumes TCP port 1723 and L2TP takes 1701. It differs on data transfer between these two VPNs. PPTP uses GRE packages  with value 47, which L2TP uses UDP packages via port 500 and 4500, and L2TP may also utilize ESP packages with value 50.


# Install PPTP server on a VPS

It’s very easy to setup PPTP VPN on any VPS running a Linux distro. I take Ubuntu 14.04 and a ramnode OpenVZ container VPS as an example (the same environment will be used in the following article), you just need to:

{% codeblock lang:bash Install pptpd %}
sudo apt-get install pptpd
{% endcodeblock %}

Then configure pptpd.conf

{% codeblock lang:bash Install pptpd %}
sudo nano /etc/pptpd.conf
{% endcodeblock %}

change the server IP and client IP

	localip 192.168.0.1
	remoteip 192.168.0.100-200

This set the pptp server IP 192.168.0.1 to its ppp device, and distribute 192.168.0.100-200 to the client side ppp device. You could change these to any value you like. But you’d better not change it besides IP range 192.168.0.0/16 and 10.0.0.0/8, since IPs in these two ranges are assigned to LAN. IPs in other range may used by the public servers, and the NAT mechanism (which will be discussed below) may confuse the traffic from the public servers and VPN clients. Localip and remoteip should be in the same network.

Then uncomment the ms-dns and add google like below or OpenDNS:

	ms-dns 8.8.8.8
	ms-dns 8.8.4.4

Now add a VPN user in `/etc/ppp/chap-secrets` file.

{% codeblock lang:bash Install pptpd %}
sudo nano /etc/ppp/chap-secrets
{% endcodeblock %}

There are four columns in this file. The first is username, choose your favorite one. The second column is service name, such as pptpd or l2tpd. You can use * to allow all services using this config line. The third column is your password, stored in plain test (which is awful :-( ). The fourth column presents the IPs allowed to use this config line. Leave it * if you want to connect the VPN from anywhere. Here’s an example:

	yourname * yourpassword *

Until now we finished all the configuration of PPTP server and we need to restart it.

{% codeblock lang:bash Install pptpd %}
sudo /etc/init.d/pptpd restart
{% endcodeblock %}

{% codeblock lang:bash Install pptpd %}
sudo service pptpd restart
{% endcodeblock %}


# Setup IPv4 Forwrding

Besides of the configuration above, we need to enable IPv4 forwarding and setup the rules in iptables for SNAT. To enable IPv4 forwarding permanently, you need to edit file `/etc/sysctl.conf` and add (or change) a following line:

	net.ipv4.ip_forward=1

Then exit to shell and execute:

{% codeblock lang:bash Install pptpd %}
sudo sysctl -p
{% endcodeblock %}


# Setup SNAT in iptables

To add a rule in iptables, you can add the following lines in `/etc/rc.local` :

	iptables -t nat -A POSTROUTING -s 192.168.0.0/24 -o venet0 -j MASQUERADE
	iptables -A FORWARD -p tcp --syn -s 192.168.0.0/24 -j TCPMSS --set-mss 1356

The first line means SNAT all the traffics from net 192.168.0.0/24 to the IP of local network interface venet0. If you setup PPTP server on a real machine, it maybe eth0 or em0. Check it with command `ifconfig`. If you adjust 192.168.0.0/24 to your favorite IPs in `localip` and `remoteip` sections above, you should replace -s 192.168.0.0/24 with the same IP range here.

The second line is a little trivial and interesting. It means iptables will change MSS field of all the TCP packages with syn in header to 1356. MSS (Maximum Segment Size) defines the maximum size of a TCP package. The default value may be 1500 in some network (1500 is the maximum size in many Ethernet lines). Since VPN will consume a few spaces in the package header, the final size of a package may be larger than the maximum size which can hold by Ethernet line.

There could be some wired problems without setting the second line. Without this, I can ping/traceroute some website successfully but cannot access the pages in browsers.

Now you could use the username and password set in /etc/ppp/chap-secrets to use PPTP VPN. Remenber to enable MPPE encryption connection.


# Enable PPP Support of VPS

PPP support is disabled by default by some VPS providers. You need to enable it manually. For a ramnode VPS, you need to login to its vps control panel ([https://vpscp.ramnode.com/login.php](https://vpscp.ramnode.com/login.php)), choose “Settings” tab at the bottom of the page and turn PPP on.

{% img /images/Setup-PPTP-Server-on-a-VPS-01.png %}

PPTP and L2TP uses PPP support by kernel, and other VPNs such as AnyConnect, OpenVPN, ShadowVPN utilize TUN/TAP support. So enable TUN/TAP as well.

In the following post, I will introduce how to setup L2TP+IPSec VPN in a OpenVZ VPS.


