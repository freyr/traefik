# Brakujące tematy

## Makefile
Na potrzeby uproszczenia procesu konfiguracji w repo znajduje się plik Makefile
(MacOS i Linux mają to narzędzie wbudowane). MAkefile pozwala na definiowanie atomowych polecen i grupowania ich w sekwencje.
Pozwala to drastycznie uprościć proces konfigurowania środowiska dla aplikacji

W tym wypadku polecenie `make create` (tylko na MacOS) lub `make-create-linux` (tylko linux) automatycznie:
1. ściągnie i uruchomi traefika
2. założy (jeśli jeszcze nie istanieje) sieć zewnętrzną `phpcon-dev`
3. Doda automatycznie uruchamiany alias dla loopbacku (wymagane hasło roota)
Kroki niewymagane zostaną automatycznie pominięte

Help dla poleceń w Makefile można uzyskać wykonując `make` bez parametrów

## PHPStorm
W konfiguracji uruchomieniowej PHPStorm znajdują się zapisane konfiguracji dla Makefile

## Automatyzacja dodawania aliasu na loopback
Dla środowisk Linuxowych polecenie aliasowania jest wbudowane w Makefile.
Rozwiązanie wzięte żywcem z: https://gist.github.com/excavador/1a12c491e9057f4a8936a5aa50207099
(nie testowałem tego :))

## Dodawanie sieci "zewnętrznej" na potrzeby komunikacji http pomiędzy stackami docker compose'a
Jest to zautomatyzowane w Makefile (target `create-network`)




# Konfiguracja jednorazowa
## Domena i przekierowanie
1. Kup domene z dostępem do modyfikacji rekordów DNS (minimum rekord A i TXT)
2. Dodaj wpis A na domene *.phpcon-dev.pl i adres ip 172.16.123.1
`*.phpcon-dev.pl.   3600  IN  A  172.16.123.1`
3. Zainstaluj Certbota (np. na MacOS:  `brew install certbot`)
4. Rozpocznij procedure generowania certyfikatu:
`sudo certbot certonly --manual`
5. Dodaj wygenerowany CHALENGE (acme) jako wpis TXT w domenie:
`$acme_chalenge.phpcon-dev.pl.   3600  IN  TXT  $chalenge_acme_value`

## Dodanie aliasu na loopback
Adres ip powinien być z zakresu prywatnego i nie kolidować z istnijącym adresem IP w twojej sieci
W targetach Makefile znajdują się skrypty automatyzujące ten proces dla MacOS

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
