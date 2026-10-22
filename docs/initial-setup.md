# Initial setup

> This guide targets the Raspberry Pi. For an x86 host (e.g. a Proxmox
> VM guest), use the Ansible playbook in `ansible/` — it covers the same
> steps (USB quirks aside) and is kept up to date.

## Network setup
The Docker host requires a static IPv4 and IPv6.
Since the homelab uses Pi-hole as its DNS server, the Docker host itself needs the router as a static DNS server:

Set these according to the home network range in `/etc/dhcpcd.conf`:
```
interface eth0
    static routers=192.168.188.1
    static domain_name_servers=192.168.188.1
    static ip_address=192.168.188.2/24
    static ip6_address=fdff:150a:4884::2/64
```
And restart: `sudo service dhcpcd restart`

Make sure to update the environment configurations in the respective `compose.yaml` files if you changed these values.

## sysctl.conf
Set the following configurations in `/etc/sysctl.conf`:
```
# IP packet forwarding (WireGuard)
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
# Re-enable Router Advertisements (Home Assistant Matter)
net.ipv6.conf.eth0.accept_ra=2
# Policy-based routing (WireGuard)
net.ipv4.conf.all.src_valid_mark=1
```

## USB-to-SATA bridge
When using a USB-to-SATA bridge, add `usb-storage.quirks=abcd:1234:u` to `/boot/cmdline.txt` where `abcd:1234` is from `lsusb`

## Router setup

Make sure to forward the required WireGuard port `UDP/47111` in the router settings.