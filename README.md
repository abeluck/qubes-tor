> **DEPRECATED** *DO NOT USE* 
> This is an old project from the very early days of Qubes.
>
> Want to run a tor vm in qubes today? Use [whonix](https://www.qubes-os.org/doc/whonix/install/)

Qubes TorVM (qubes-tor)
==========================

Qubes TorVM is a ProxyVM service that provides torified networking to all its
clients.

By default, any AppVM using the TorVM as its NetVM will be fully torified, so
even applications that are not Tor aware will be unable to access the outside
network directly.

Moreover, AppVMs running behind a TorVM are not able to access globally
identifying information (IP address and MAC address).

Due to the nature of the Tor network, only IPv4 TCP and DNS traffic is allowed.
All non-DNS UDP and IPv6 traffic is silently dropped.

See [this article](http://theinvisiblethings.blogspot.com/2011/09/playing-with-qubes-networking-for-fun.html) for a description of the concept, architecture, and the original implementation.

## Warning + Disclaimer

1. Qubes TorVM is produced independently from the Tor(R) anonymity software and
   carries no guarantee from The Tor Project about quality, suitability or
   anything else.

2. Qubes TorVM is not a magic anonymizing solution. Protecting your identity
   requires a change in behavior. Read the "Protecting Anonymity" section
   below.

3. Traffic originating from the TorVM itself **IS NOT** routed through Tor.
   This includes system updates to the TorVM. Only traffic from VMs using TorVM
   as their NetVM is torified.

Installation
============


0. *(Optional)* If you want to use a separate vm template for your TorVM

        qvm-clone fedora-20-x64 fedora-20-x64-net

1. In dom0, create a proxy vm and disable unnecessary services and enable qubes-tor


        qvm-create -p torvm
        qvm-service torvm -d qubes-netwatcher
        qvm-service torvm -d qubes-firewall
        qvm-service torvm -e qubes-tor
          
        # if you  created a new template in the previous step
        qvm-prefs torvm -s template fedora-20-x64-net

2. From your template vm, install the torproject Fedora repo

        sudo yum install qubes-tor-repo

3. Then, in the template, install the TorVM init scripts

        sudo yum install qubes-tor

5. Configure an AppVM to use TorVM as its netvm (example a vm named anon-web)

        qvm-prefs -s anon-web netvm torvm
	... repeat for other appvms ...

6. Shutdown templateVM.
7. Set prefs of torvm to use your default netvm or firewallvm as its NetVM
8. Start the TorVM and any AppVM you have configured
9. Execute in TorVM (will be not necessary in R2 Beta3):

        sudo mkdir /rw/usrlocal/etc/qubes-tor
        sudo touch /rw/usrlocal/etc/qubes-tor/torrc
        sudo service qubes-tor restart

10. From the AppVM, verify torified connectivity

        curl https://check.torproject.org


### Troubleshooting ###


1. Check if the qubes-tor service is running (on the torvm)

        [user@torvm] $ sudo service qubes-tor status

2. Tor logs to syslog, so to view messages use

        [user@torvm] $ sudo grep Tor /var/log/messages

3. Restart the qubes-tor service (and repeat 1-2)

        [user@torvm] $ sudo service qubes-tor restart

Usage
=====

Applications should "just work" behind a TorVM, however there are some steps
you can take to protect anonymity and increase performance.

## Protecting Anonymity

The TorVM only purports to prevent the leaking of two identifiers:

1. WAN IP Address
2. NIC MAC Address

This is accomplished through transparent TCP and transparent DNS proxying by
the TorVM.

The TorVM cannot anonymize information stored or transmitted from your AppVMs
behind the TorVM. 

*Non-comprehensive* list of identifiers TorVM does not protect:

* Time zone
* User names and real name
* Name+version of any client (e.g. IRC leaks name+version through CTCP)
* Metadata in files (e.g., exif data in images, author name in PDFs)
* License keys of non-free software

### Further Reading

* [Information on protocol leaks](https://trac.torproject.org/projects/tor/wiki/doc/TorifyHOWTO#Protocolleaks)
* [Official Tor Usage Warning](https://www.torproject.org/download/download-easy.html.en#warning)
* [Tor Browser Design](https://www.torproject.org/projects/torbrowser/design/)


## Performance

In order to mitigate identity correlation TorVM makes use of Tor's new [stream
isolation feature][stream-isolation]. Read "Threat Model" below for more
information.

However, this isn't desirable in all situations, particularly web browsing.
These days loading a single web page requires fetching resources (images,
javascript, css) from a dozen or more remote sources. Moreover, the use of
IsolateDestAddr in a modern web browser may create very uncommon HTTP behavior
patterns, that could ease fingerprinting.

Additionally, you might have some apps that you want to ensure always share a
Tor circuit or always get their own.

For these reasons TorVM ships with two open SOCKS5 ports that provide Tor
access with different stream isolation settings:

* Port 9050 - Isolates by SOCKS Auth and client address only  
              Each AppVM gets its own circuit, and each app using a unique SOCKS
              user/pass gets its own circuit
* Port 9049 - Isolates client + estination port, address, and by SOCKS Auth
              Same as default settings listed above, but additionally traffic
              is isolated based on destination port and destination address.


## Custom Tor Configuration

Default tor settings are found in the following file and are the same across
all TorVMs.

      /usr/lib/qubes-tor/torrc

You can override these settings in your TorVM, or provide your own custom
settings by appending them to:

      /rw/usrlocal/etc/qubes-tor/torrc

For information on tor configuration settings `man tor`

Threat Model
============

TorVM assumes the same Adversary Model as [TorBrowser][tor-threats], but does
not, by itself, have the same security and privacy requirements.

## Proxy Obedience

The primary security requirement of TorVM is *Proxy Obedience*.

Client AppVMs MUST NOT bypass the Tor network and access the local physical
network, internal Qubes network, or the external physical network.

Proxy Obedience is assured through the following:

1. All TCP traffic from client VMs is routed through Tor
2. All DNS traffic from client VMs is routed through Tor
3. All non-DNS UDP traffic from client VMs is dropped
4. Reliance on the [Qubes OS network model][qubes-net] to enforce isolation

## Mitigate Identity Correlation

TorVM SHOULD prevent identity correlation among network services.

Without stream isolation, all traffic from different activities or "identities"
in different applications (e.g., web browser, IRC, email) end up being routed
through the same tor circuit. An adversary could correlate this activity to a
single pseudonym.

TorVM uses the default stream isolation settings for transparently torified
traffic. While more paranoid options are available, they are not enabled by
default because they decrease performance and in most cases don't help
anonymity (see [this tor-talk thread][stream-isolation-explained])

By default TorVM does not use the most paranoid stream isolation settings for
transparently torified traffic due to performance concerns. By default TorVM
ensures that each AppVM will use a separate tor circuit (`IsolateClientAddr`).

For more paranoid use cases the SOCKS proxy port 9049 is provided that has all
stream isolation options enabled. User applications will require manual
configuration to use this socks port.


Future Work
===========
* Integrate Vidalia
* Create Tor Browser packages w/out bundled tor
* Use local DNS cache to speedup queries (pdnsd)
* Support arbitrary [DNS queries][dns]
* Fix Tor's openssl complaint
* Support custom firewall rules (to support running a relay)

Acknowledgements
================

Qubes TorVM is inspired by much of the previous work done in this area of
transparent torified solutions. Notably the following:

* [adrelanos](mailto:adrelanos@riseup.net) for his work on [aos/Whonix](https://sourceforge.net/p/whonix/wiki/Security/)
* The [Tor Project wiki](https://trac.torproject.org/projects/tor/wiki/doc/TorifyHOWTO)
* And the many people who contributed to discussions on [tor-talk](https://lists.torproject.org/pipermail/tor-talk/)

[stream-isolation]: https://gitweb.torproject.org/torspec.git/blob/HEAD:/proposals/171-separate-streams.txt
[stream-isolation-explained]: https://lists.torproject.org/pipermail/tor-talk/2012-May/024403.html
[tor-threats]: https://www.torproject.org/projects/torbrowser/design/#adversary
[qubes-net]: http://wiki.qubes-os.org/trac/wiki/QubesNet
[dns]: https://tails.boum.org/todo/support_arbitrary_dns_queries/

