title: L2TP+IPSec on VPS
date: 2015-05-21 14:59:34
tags:
  - L2TP
  - IPSec
  - VPS
  - VPN
categories:
  - Fire on the Wall
---

L2TP+IPSec is another way to setup VPN on a VPS. L2TP consumes 1701 TCP port to maintain connection and 500/4500 UDP to transfer data. It’s very easy to implement L2TP and IPSec on a Ubuntu 14.04 server.

Before setting up L2TP/IPSec environment, you need to enable PPP support for VPS. See details on section **“Enable PPP Support of VPS”** of my previous post "[Setup PPTP Server on a VPS](/2015/05/20/Setup-PPTP-Server-on-a-VPS/)" to enable PPP support on RamNode VPS.

When I first installed xl2tpd and openswan, it occured to me the following errors and refused my iPhone VPN connection:

	May 19 05:48:46 xxx xl2tpd[1343]: result_code_avp: result code endianness fix for buggy Apple client. network=768, le=3

If you get the same error message, just follow step by step with me to setup L2TP+IPSec VPN.


# Install xl2tpd and openwan

Here I use openswan as my IPSec server. Just use the following commands to install xl2tpd and openswan:

{% codeblock lang:bash Install pptpd %}
sudo apt-get install openswan ppp xl2tpd
{% endcodeblock %}


# Configure xl2tpd

We need to configure two files for xl2tpd: `/etc/xl2tpd/xl2tpd.conf` and `/etc/ppp/options.xl2tpd`

Here’s an example of `/etc/xl2tpd/xl2tpd.conf` :

	[global]
	listen-addr = 106.186.127.239

	[lns default]
	ip range = 10.20.0.2-10.20.0.100
	local ip = 10.20.0.1
	assign ip = yes
	length bit = yes
	refuse pap = yes
	require authentication = yes
	pppoptfile = /etc/ppp/options.xl2tpd


“ip range” defined IPs distributed to the client side and “local ip” is assigned to the server side. pppoptfile defines the detailed config file for xl2tpd.

Then create file `/etc/ppp/options.xl2tpd` and add:

	ms-dns 8.8.8.8
	ms-dns 8.8.4.4
	noccp
	asyncmap 0
	auth
	crtscts
	lock
	hide-password
	modem
	mru 1200
	nodefaultroute
	debug
	mtu 1200
	proxyarp
	lcp-echo-interval 30
	lcp-echo-failure 4
	ipcp-accept-local
	ipcp-accept-remote
	noipx
	idle 1800
	connect-delay 5000


# Configure OpenSwan IPSec

IPSec acts as a role to provide a secure routine for transferring data. OpenSwan is a good choice to set up a simple IPSec. Note that there are many IPSec choices and they should be exclusively installed in your system. And whatever IPSec server you installed, the command to call them is only “ipsec“. Use the following command to identify which IPSec service you’re using now.

	ipsec --version

The config file for OpenSwan is /etc/ipsec.conf. Actually this file name is identical for all IPSec service, which the content differs anyway. When you installed another IPSec service with apt-get, you need to change the format and contents of this file.

Here’s an example of this file:

	version 2.0

	config setup
	    dumpdir=/var/run/pluto/
	    nat_traversal=yes
	    virtual_private=%v4:10.0.0.0/8,%v4:192.168.0.0/16,%v4:172.16.0.0/12,%v4:25.0.0.0/8,%v6:fd00::/8,%v6:fe80::/10
	    protostack=netkey
	    force_keepalive=yes
	    keep_alive=60

	conn l2tp-psk
	    authby=secret
	    pfs=no
	    auto=add
	    keyingtries=3
	    type=transport
	    left=1.2.3.4 # change to your own IP
	    leftprotoport=17/1701
	    right=%any
	    rightprotoport=17/%any

The “virtual_private” line shows which network could use this IPSec routine, leave it as what it is. The only line you need to change is “left”, which should be your VPS IP address.

Then we need to create and edit file `/etc/ipsec.secrets`.

	 : PSK "sharedpassword"

**Note that there’s blank before and after colon!**

“sharedpassword” should be used as the “shared secret” when you connect L2TP.


# Add L2TP VPN account

Edit file `/etc/ppp/chap-secrets`, which is the same as PPTP server. Use the format like this:

	yourname * yourpassword *

# Setup IPv4 forwarding and iptables rules

It’s also the same as PPTP server, you just need to edit file `/etc/sysctl.conf` and add (or change) a following line:

	net.ipv4.ip_forward=1

Then exit to shell and execute:

{% codeblock lang:bash Install pptpd %}
sudo sysctl -p
{% endcodeblock %}

To add iptables rules,  add the following lines in `/etc/rc.local` :

	iptables -t nat -A POSTROUTING -s 10.20.0.0/24 -o venet0 -j MASQUERADE
	iptables -A FORWARD -p tcp --syn -s 10.20.0.0/24 -j TCPMSS --set-mss 1356

Note “-s 10.20.0.0/24” should be the net range defined in “ip range” section of `/etc/xl2tpd/xl2tpd.conf` .

At last, restart xl2tpd and ipsec:

{% codeblock lang:bash Install pptpd %}
sudo service xl2tpd restart
sudo service ipsec restart
{% endcodeblock %}

Enjoy you surfing! ;)
