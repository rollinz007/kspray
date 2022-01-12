# kspray
kspray is useful on untrusted/non-domain joined Kali host to perform:
- Password spraying using kerberos
- DC/KDC enumeration (KDCs are ranomly selected for each authentication attempt)
- User enumeration (Positivly identifies users if you didn't already know them)

# Requirements
- Must run as root
- kinit (apt-get install krb5-user)

# Usage
./kspray.sh [DOMAIN] [usernames.txt] [password]

# Example
./kspray.sh CORP.NET users.txt Spring2018

# Demonstration Video
https://youtu.be/qIHhLfgTl0A
