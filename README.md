# README

## Custom domain
### Add record A to point to custom private IP
DNS *.phpcon-dev.pl.   3600  IN  A  172.16.123.1
### Install CertBot
brew install certbot

### Generate cert with DNS chalenge.
sudo certbot certonly --manual

### Add TXT record with CertBot chalenge
DNS $acme_chalenge.phpcon-dev.pl.   3600  IN  TXT  $chalenge_acme_value

## Aliasing loopback
### MacOS
ifconfig lo0 alias 172.16.123.1 # to add a new loopback alias

### Linux
ifconfig lo:0 172.16.123.1 netmask 255.240.0.0 up

### Windows?
netsh interface ipv4 show interface # to get the interface name
netsh interface ipv4 set interface interface="$interfaceName" dhcpstaticipcoexistence=enabled #enable feature dhcp/static
netsh interface ipv4 add address "$interfaceName" 172.16.123.1 255.240.0.0 #set static ip
ipconfig /all # check if it works

### Fallback?
/etc/hosts or c:\Windows\System32\Drivers\etc\hosts and enter every domain manually
