# qubes-tor: Default configuration
###################################################################
# This file is AUTO-GENERATED on startup by the qubes-tor service #
#                                                                 #
# Place your own tor settings in /rw/config/qubes-tor/torrc       #
###################################################################

DataDirectory DATA_DIRECTORY
SocksPort "QUBES_IP:TOR_SOCKS_ISOLATED_PORT IsolateClientAddr IsolateSOCKSAuth IsolateDestPort IsolateDestAddr"
SocksPort "QUBES_IP:TOR_SOCKS_PORT IsolateClientAddr IsolateSOCKSAuth"
TransPort "QUBES_IP:TOR_TRANS_PORT IsolateClientAddr"
DNSPort "QUBES_IP:53 IsolateClientAddr IsolateSOCKSAuth"
ControlPort TOR_CONTROL_PORT
AutomapHostsOnResolve 1
VirtualAddrNetwork "VIRTUAL_ADDR_NET"

