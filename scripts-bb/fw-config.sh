#!/bin/bash

##########........Script Setup........##########
###Script Text Font and Appearance
bold=$(tput bold)
normal=$(tput sgr0)

###A basic Graphical Display to use in place of sleep command
function WaitingDots {
    n=0
    while [ $n -lt $timer ] ; do
        sleep 0.125s; echo -n " "
        sleep 0.125s; echo -n "."
        sleep 0.125s; echo -n " "
        sleep 0.125s; echo -n "."
        sleep 0.125s; echo -n " "
        sleep 0.125s; echo -n "."
        sleep 0.125s; echo -n " "
        sleep 0.125s
        n=$[n+1]
        echo -n "${bold}$n${normal}" 
    done
    sleep 0.125s
    echo -e "\n"
    sleep 0.25s
}

###Port Forward iptables config via function: execPFConfig 
function execPFConfig {
    portforward=$(< /tmp/gluetun/forwarded_port)

    #Check if Static NAT to server via VPN inbound port is present
    iptables-legacy -t nat -C PREROUTING -i tun0 -p tcp -m tcp --dport $portforward -j DNAT --to-destination $T4_SERVER_IP
    if [ $? = 1 ]; then
        #Port Forward is not present
        iptables-legacy -t nat -I PREROUTING 1 -i tun0 -p tcp -m tcp --dport $portforward -j DNAT --to-destination $T4_SERVER_IP
        iptables-legacy -t nat -I PREROUTING 1 -i tun0 -p udp -m udp --dport $portforward -j DNAT --to-destination $T4_SERVER_IP
    else
        #Port Forward is present so skipping
        echo "Inbound TCP and UDP Port Forward to ${bold}$portforward${normal} already exists! Moving on..."
    fi

    #Check if Hide NAT from servers VLAN through VPN interface is present
    iptables-legacy -t nat -C POSTROUTING -o tun0 -j MASQUERADE
    if [ $? = 1 ]; then
        #Hide NAT is not present
        iptables-legacy -t nat -A POSTROUTING -o tun0 -j MASQUERADE
    else
        #Hide NAT is present so skipping
        echo "Outbound Hide NAT through VPN interface ${bold}tun0${normal} already exists! Moving on..."
    fi

    #Check if access rule allowing established connections inbound through VPN is present
    iptables-legacy -C FORWARD -i tun0 -o eth0 -d $T4_SERVER_IP -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    if [ $? = 1 ]; then
        #Access rule is not present
        iptables-legacy -I FORWARD 1 -i tun0 -o eth0 -d $T4_SERVER_IP -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    else
        #Access rule is present so skipping
        echo "Rule to allow existing incoming AND related sessions to server through VPN already exists! Moving on..."
    fi

    #Check if Access Rule to allow new connections to server from VPN inbound port TCP is present
    iptables-legacy -C FORWARD -i tun0 -o eth0 -d $T4_SERVER_IP -p tcp --dport $portforward -m conntrack --ctstate ESTABLISHED,RELATED,NEW -j ACCEPT
    if [ $? = 1 ]; then
        #Access rule is not present
        iptables-legacy -I FORWARD 1 -i tun0 -o eth0 -d $T4_SERVER_IP -p tcp --dport $portforward -m conntrack --ctstate ESTABLISHED,RELATED,NEW -j ACCEPT
    else
        #Access rule is present so skipping
        echo "Rule to allow new TCP sessions to server through VPN already exists! Moving on..."
    fi
    
    #Check if Access Rule to allow new connections to server from VPN inbound port UDP is present
    iptables-legacy -C FORWARD -i tun0 -o eth0 -d $T4_SERVER_IP -p udp --dport $portforward -m conntrack --ctstate ESTABLISHED,RELATED,NEW -j ACCEPT
    if [ $? = 1 ]; then
        #Access rule is not present
        iptables-legacy -I FORWARD 1 -i tun0 -o eth0 -d $T4_SERVER_IP -p udp --dport $portforward -m conntrack --ctstate ESTABLISHED,RELATED,NEW -j ACCEPT
    else
        #Access rule is present so skipping
        echo "Rule to allow new UDP sessions to server through VPN already exists! Moving on..."
    fi

    #Check if Access Rule to allow new outbound connections through VPN from Servers VLAN is present
    iptables-legacy -C FORWARD -i eth0 -o tun0 -j ACCEPT
    if [ $? = 1 ]; then
        #Access rule is not present
        iptables-legacy -I FORWARD 1 -i eth0 -o tun0 -j ACCEPT
    else
        #Access rule is present so skipping
        echo "Access Rule already exists to allow new connections outbound through VPN! Moving on..."
    fi
}


echo -e "\n Giving gluetun a chance to startup"
sleep 50s
timer="15"
echo -e "\nBeginning fw (iptables) config in $timer seconds...\n"
WaitingDots

echo "${normal}Validating if portfoward has been set with VPN" 

if [ -f /tmp/gluetun/forwarded_port ]; then
    portforward=$(< /tmp/gluetun/forwarded_port)
    echo -e "Configuring iptables with inbound port: $portforward\n"
    execPFConfig
else
    echo "Port forward not yet established. Waiting 15 seconds before trying again"
    timer="15"
    WaitingDots
    if [ -f /tmp/gluetun/forwarded_port ]; then
        portforward=$(< /tmp/gluetun/forwarded_port)
        echo -e "Configuring iptables with inbound port: $portforward\n"
        execPFConfig
    else
        echo "Port Forward not configured. You can try to execute this script yourself at the directory:"
        echo "/root/scripts/fw-config.sh"
    fi
fi

echo -e "\nRules are updated"
echo -e "\n${bold}Current iptables rule printout:${normal}\n"
iptables-legacy-save


