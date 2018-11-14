#!/bin/bash

# steps, advancing to subsequent step assumes failure
# *. Can we ping external address (say google DNS 8.8.8.8)
# *. Find the route for internet traffic out of the host
# *. Is the required interface up
# *. Does it have an IP address - if not should it get one from dhcp or static?
# *. Is host part of the correct subnet? 
# *. Is the gateway IP pingable?
# Example - host is 192.add.re.ss but gateway IP for defualt route is 172.add.re.ss then fail
# 
if [ -f networkCheckFunctions.sh ]
then
	source networkCheckFunctions.sh
else
	echo Error - no networkCheckFunctions file found
fi
if [ $# == 1 ]
then 
	EXT_ADDRESS=$1
else
	EXT_ADDRESS='8.8.8.8'
fi
NETSTAT=$( which netstat )
PING=$( which ping )
IP=$( which ip )
TRACEROUTE=$( which traceroute )
ROUTE=$( which route )
IFCONFIG=$( which ifconfig )
ETHTOOL=$(which ethtool )
DHCLIENT=$( which dhclient )
IFUP=$( which ifup )
LOG=$PWD/networkCheck.log
desiredCommands='ifconfig netstat ping traceroute ip route' 
for c in $desiredCommands
do
	COM=$(which $c)
	if [ $? -ne 0 ]
	then 
		echo Recommend installing tool $c to assist network debugging 
	fi
done

if pingCheck $EXT_ADDRESS
then 
	echo pingCheck to external address $EXT_ADDRESS succeeded...exiting
	exit 0
fi
echo Ping to $EXT_ADDRESS  fail, proceeding with checks  

getDefaultConfigs

# is the interface up?
echo Checking the interface $INTERFACE is up ... 
if ! $IFCONFIG $INTERFACE &> $LOG 
then
	echo The default interface $INTERFACE is not up, this is a possible problem to investigate
	commandExists ifup && echo Try $IFUP $INTERFACE and check $LOG for errors
	exit 1
else
	echo Default interface is up
fi
# Does the interface have an IP?
echo 'Checking the interface has an IP ...'
if getInterfaceIP $INTERFACE
then
	echo Interface $INTERFACE has IP $INTERFACEIP
else
	echo Interface $INTERFACE has no IP
	echo Some points to investigate
	echo Check whether it should get one via DHCP or static
	echo Does /etc/network/interfaces reference dhcp for $INTERFACE
	echo If so, is the dhclient running?....
	if commandExists dhclient
	then
		echo Try pgrep -f dhclient
		echo if it is not running and it should be, try to start it...
		echo $DHCLIENT -v $INTERFACE
		echo grep DHCP $SYSTEMLOG and check for errors
		echo check dhcp leases in /var/lib/dhcp/*leases
	else
		echo No dhclient found
	fi
	exit 1
fi

# Assuming host configs are ok, now lets check we can reach the gateway
echo Checking if we can reach the gateway IP $GATEWAYIP ...
if ! pingCheck $GATEWAYIP
then
	echo Cannot ping Gateway IP $GATEWAYIP
	echo Possible cause is the interface IP is not on the correct subnet
	echo $INTERFACE has address $INTERFACEIP and mask $SUBNETMASK
	exit 1
else
	echo We can ping the gateway, so how far does traffic reach
	if commandExists traceroute
	then
		$TRACEROUTE -g $GATEWAYIP $EXT_ADDRESS | tee -a $LOG
	else
		echo Install traceroute to see how far packets are routed, use command
		echo traceroute -g $GATEWAYIP $EXT_ADDRESS
	fi
fi
