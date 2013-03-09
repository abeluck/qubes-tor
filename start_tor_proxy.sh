#!/bin/sh
# 
# The Qubes OS Project, http://www.qubes-os.org
#
# Copyright (C) 2012-2013 Abel Luck <abel@outcomedubious.im>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#

killall tor
QUBES_IP=$(xenstore-read qubes_ip)
TOR_TRANS_PORT=9040 # maximum circuit isolation
TOR_SOCKS_PORT=9050 # less circuit isolation
TOR_SOCKS_ISOLATED_PORT=9049 # maximum circuit isolation
TOR_CONTROL_PORT=0 # 0 = disabled
DATA_DIRECTORY=/rw/usrlocal/lib/qubes-tor

if [ X$QUBES_IP == X ]; then
echo "Error getting QUBES IP!"
echo "Not starting Tor, but setting the traffic redirection anyway to prevent leaks."
QUBES_IP="127.0.0.1"
else

if [ ! -d "$DATA_DIRECTORY" ]; then
	mkdir -p $DATA_DIRECTORY
fi

/usr/bin/tor \
--DataDirectory $DATA_DIRECTORY \
--SocksPort "$QUBES_IP:$TOR_SOCKS_ISOLATED_PORT IsolateClientAddr IsolateSOCKSAuth IsolateDestPort IsolateDestAddr" \
--SocksPort "$QUBES_IP:$TOR_SOCKS_PORT IsolateClientAddr IsolateSOCKSAuth" \
--TransPort "$QUBES_IP:$TOR_TRANS_PORT IsolateClientAddr IsolateDestPort IsolateDestAddr" \
--DNSPort "$QUBES_IP:53 IsolateClientAddr IsolateSOCKSAuth" \
--ControlPort $TOR_CONTROL_PORT \
--AutomapHostsOnResolve 1 \
--VirtualAddrNetwork "172.16.0.0/12" \
--RunAsDaemon 1 \
--Log "notice syslog" \
--PIDFile /var/run/qubes-tor.pid \
|| echo "Error starting Tor!"

fi

echo "0" > /proc/sys/net/ipv4/ip_forward
/sbin/iptables -F
/sbin/iptables -P INPUT DROP
/sbin/iptables -P FORWARD ACCEPT
/sbin/iptables -P OUTPUT ACCEPT
/sbin/iptables -A INPUT -i vif+ -p udp -m udp --dport 53 -j ACCEPT
/sbin/iptables -A INPUT -i vif+ -p tcp -m tcp --dport $TOR_TRANS_PORT -j ACCEPT
/sbin/iptables -A INPUT -i vif+ -p tcp -m tcp --dport $TOR_SOCKS_PORT -j ACCEPT
/sbin/iptables -A INPUT -i vif+ -p tcp -m tcp --dport $TOR_SOCKS_ISOLATED_PORT -j ACCEPT
/sbin/iptables -A INPUT -i vif+ -p tcp -m tcp --dport $TOR_CONTROL_PORT -j ACCEPT
/sbin/iptables -A INPUT -i vif+ -p udp -m udp -j DROP
/sbin/iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
/sbin/iptables -A INPUT -i lo -j ACCEPT
/sbin/iptables -A INPUT -j REJECT --reject-with icmp-host-prohibited

# nat rules
/sbin/iptables -t nat -F
/sbin/iptables -t nat -P PREROUTING ACCEPT
/sbin/iptables -t nat -P INPUT ACCEPT
/sbin/iptables -t nat -P OUTPUT ACCEPT
/sbin/iptables -t nat -P POSTROUTING ACCEPT
/sbin/iptables -t nat -A PREROUTING -i vif+ -p udp -m udp --dport 53 -j DNAT --to-destination $QUBES_IP:53
/sbin/iptables -t nat -A PREROUTING -i vif+ -p tcp -m tcp --dport $TOR_SOCKS_ISOLATED_PORT -j DNAT --to-destination $QUBES_IP:$TOR_SOCKS_ISOLATED_PORT
/sbin/iptables -t nat -A PREROUTING -i vif+ -p tcp -m tcp --dport $TOR_SOCKS_PORT -j DNAT --to-destination $QUBES_IP:$TOR_SOCKS_PORT
/sbin/iptables -t nat -A PREROUTING -i vif+ -p tcp -j DNAT --to-destination $QUBES_IP:$TOR_TRANS_PORT
echo "1" > /proc/sys/net/ipv4/ip_forward  

# completely disable ipv6
/sbin/ip6tables -P INPUT DROP
/sbin/ip6tables -P OUTPUT DROP
/sbin/ip6tables -P FORWARD DROP
/sbin/ip6tables -F

for iface in `ls /proc/sys/net/ipv6/conf/vif*/disable_ipv6`; do
	echo "1" > $iface
done

