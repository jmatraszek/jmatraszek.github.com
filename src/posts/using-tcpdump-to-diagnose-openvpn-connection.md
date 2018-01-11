extends: default.liquid

title: Using tcpdump to diagnose OpenVPN connection
date: 14 December 2017 21:19:00 +0100
---

Using tcpdump to diagnose OpenVPN connection
===================

Recently, I encountered a weird problem in my network setup. I've got router box
running OPNsense. On the router I also run an OpenVPN server so I can access my
LAN from the outside. This works perfectly. I wanted to use OpenVPN to access
my work computer (it's inside corporate network with no chance for port
forwarding). Figured out that the easiest solution would be to have an OpenVPN client
(that connects to the server on my router) always running. And this was
behaving strangely... VPN connection was up and running, I could access home LAN
from my workstation, but I could not access my work machine from within home
LAN.

The desired setup should look like this:

```
+-------------+
| Router      |
|             |                     +-------------+
|      +------+                     | Office      |
|  +---| VPN  |------Internet-------| workstation |
|  |   |server|                     |             |
+------+------+                     +-------------+
   |
   |
  LAN
   |
   |
+-------------+
| Local       |
| workstation |
|             |
+-------------+
```

Some details of my configuration:

* My LAN network is `192.168.160.0/21`;
* OpenVPN network is `10.168.164.0/24`;
* OpenVPN is running in `tun` mode with topology `subnet` and `client-to-client` connections enabled;
* `10.168.164.2` is the machine I was trying to reach — this is the office workstation;
* `192.168.161.1` is a machine inside LAN from which I was trying to reach the office workstation - this is the local workstation;
* `igb1` is LAN's interface on router, `ovpns1` is VPN's interface on router; `tun0` is VPN's interface on the office workstation.

I used curl to access the office workstation. I expected one packet (`SYN`, first step of a three-way TCP handshake) to be sent from my home machine, and one packet (`RST`, since port 80 is closed) to be sent to my home machine from my work machine. I started tinkering with `tcpdump` to see what is going on... first on the client (I could log into it, because I left an open SSH tunnel):

```
$ sudo tcpdump -i tun0
[...]
```

No packets captured, nothing reached my client. Then I started listening on VPN's interface on router to see if anything reached OpenVPN server so it can send it to the client:

```
# tcpdump -a -i ovpns1 net 10.168.164.0/24
[...]
```

Nothing. So I sniffed LAN's interface to verify packets reach LAN side on router.

```
# tcpdump -i igb1 net 10.168.164.0/24
[...]

21:35:23.740269 IP 192.168.161.1.41506 > 10.168.164.2.http: Flags [S], seq
152436380, win 29200, options [mss 1460,sackOK,TS val 1909335576 ecr
0,nop,wscale 7], length 0

21:35:24.749749 IP 192.168.161.1.41506 > 10.168.164.2.http: Flags [S], seq
152436380, win 29200, options [mss 1460,sackOK,TS val 1909336586 ecr
0,nop,wscale 7], length 0

21:35:26.959746 IP 192.168.161.1.41506 > 10.168.164.2.http: Flags [S], seq
152436380, win 29200, options [mss 1460,sackOK,TS val 1909338796 ecr
0,nop,wscale 7], length 0

21:35:31.013065 IP 192.168.161.1.41506 > 10.168.164.2.http: Flags [S], seq
152436380, win 29200, options [mss 1460,sackOK,TS val 1909342849 ecr
0,nop,wscale 7], length 0

21:35:39.119756 IP 192.168.161.1.41506 > 10.168.164.2.http: Flags [S], seq
152436380, win 29200, options [mss 1460,sackOK,TS val 1909350955 ecr
0,nop,wscale 7], length 0

21:35:55.546429 IP 192.168.161.1.41506 > 10.168.164.2.http: Flags [S], seq
152436380, win 29200, options [mss 1460,sackOK,TS val 1909367382 ecr
0,nop,wscale 7], length 0

21:36:27.973069 IP 192.168.161.1.41506 > 10.168.164.2.http: Flags [S], seq
152436380, win 29200, options [mss 1460,sackOK,TS val 1909399807 ecr
0,nop,wscale 7], length 0
```

Not exactly what I expected, but at least I have something. The packet from my machine reached router on LAN's interface, but there was no response. We can see that curl was trying to reconnect (after 1, 2, 4, 8, 16, 32 seconds). So I tried accessing the work machine directly from router's command line (bypassing LAN's interface) while still listening on `ovpns1`:

```
# tcpdump -a -i ovpns1 net 10.168.164.2/32
[...]

15:56:23.815123 IP router.home.lan.53122 > 10.168.164.2.http: Flags [S], seq
2365664724, win 65228, options [mss 1460,nop,wscale 7,sackOK,TS val 2658382376
ecr 0], length 0

15:56:23.827799 IP 10.168.164.2.http > router.home.lan.53122: Flags [R.], seq
0, ack 2365664725, win 0, length 0
```

Okay, this worked. So it means the problem only appears when the packet enters through LAN. This got me thinking... and suddenly everything clicked! I've got WAN failover configured and a firewall rule that routes every LAN packet to the WAN gateway group! So there is no way I can access OpenVPN's client from LAN, because all traffic goes directly to the gateway. The fix was to add a rule with a higher priority for OpenVPN's network:

```
# pfctl -sr

pass in quick on igb1 inet from any to (openvpn:network) flags S/SA keep state
label "USER_RULE: Allow traffic from LAN to OpenVPN."

pass in quick on igb1 route-to (igb0 XX.XX.XX.XX) sticky-address inet all flags
S/SA keep state label "USER_RULE: Default allow LAN to any rule"
```

And everything worked properly.

Test from the home workstation:

```
$ curl 10.168.164.2
curl: (7) Failed to connect to 10.168.164.2 port 80: Connection refused
```

Packets enter the router on LAN interface:

```
# tcpdump -i igb1 net 10.168.164.0/24
[...]

21:43:53.830956 IP 192.168.161.1.41566 > 10.168.164.2.http: Flags [S], seq
457019163, win 29200, options [mss 1460,sackOK,TS val 1909845655 ecr
0,nop,wscale 7], length 0

21:43:53.841831 IP 10.168.164.2.http > 192.168.161.1.41566: Flags [R.], seq 0,
ack 457019164, win 0, length 0
```

Go through OpenVPN's interface:

```
# tcpdump -a -i ovpns1 net 10.168.164.0/24
[...]

21:43:53.831042 IP 192.168.161.1.41566 > 10.168.164.2.http: Flags [S], seq
457019163, win 29200, options [mss 1460,sackOK,TS val 1909845655 ecr
0,nop,wscale 7], length 0

21:43:53.841763 IP 10.168.164.2.http > 192.168.161.1.41566: Flags [R.], seq 0,
ack 457019164, win 0, length 0
```

And reach the office workstation:

```
$ sudo tcpdump -i tun0
[...]

21:43:53.838111 IP 192.168.161.1.41566 > 10.168.164.2.http: Flags [S], seq
457019163, win 29200, options [mss 1357,sackOK,TS val 1909845655 ecr
0,nop,wscale 7], length 0

21:43:53.838167 IP 10.168.164.2.http > 192.168.161.1.41566: Flags [R.], seq 0,
ack 457019164, win 0, length 0
```

Now it feels like a rookie mistake and something that can be done only by an inexperienced network administrators like me, but I decided to post the solution here — maybe it will spare some time for people who may have a similiar issue.
