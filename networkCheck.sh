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
EXT_ADDRESS='8.8.8.8'
NETSTAT=$( which netstat )
PING=$( which ping )
IP=$( which ip )
TRACEROUTE=$( which traceroute )
ROUTE=$( which route )
IFCONFIG=$( which ifconfig )
ETHTOOL=$(which ethtool )
desiredCommands='ifconfig netstat ping traceroute ip route' 
for c in $desiredCommands
do
	COM=$(which $c)
	if [ $? -ne 0 ]
	then 
		echo Recommend installing tool $c to assist network debugging 
	fi
done

commandExists () {
	COM=$( which $1 )
	if [ $? -ne 0 ]
	then
		echo No command $1 found
		return 1
	else
		return 0
	fi
}

pingCheck () {
	commandExists ping || return 1
	$PING -q -c 5 -W 2 $1 1> /dev/null || return 1
	return 0	
}
onSuccess () {
	echo $1  succeeded, exiting
	exit 0
}
getDefaultRoute () {
	commandExists netstat || return 1
}
getDefaultInterface () {
	commandExists netstat || return 1
	INTERFACE=$( netstat -r | grep default | awk {'print $NF'} ) # interface is the last field
}
isIPv4 () {
	if ! echo $1 | egrep -q  "([0-9]{1,3}\.)[0-9]{1,3}"
	then
		return 1
	else
		return 0
	fi
}

getDefaultGateway () {
	commandExists netstat || return 1
	GATEWAYIP=$( $NETSTAT -r | grep default | awk {'print $2'})
	# check gateway matches IP regex
	if ! echo $GATEWAYIP | egrep -q  "([0-9]{1,3}\.){3}[0-9]{1,3}"
	then
		echo Cannot determine default Gateway. $GATEWAYIP is not valid
		GATEWAYIP=''
	fi
}
getDefaultConfigs () {
	getDefaultInterface
	getDefaultGateway
	echo Gateway IP $GATEWAYIP
	echo Interface $INTERFACE
	return 0
}
getInterfaceIP () {
	commandExists ifconfig || return 1
	INTERFACEIP=$( ifconfig $INTERFACE | grep 'inet addr' | awk {'print $2'} | cut -d: -f2 )
	isIPv4 $INTERFACEIP || return 1
	return 0
}
#pingCheck $EXT_ADDRESS && onSuccess pingCheck || echo 'Ping fail, proceeding with checks'  

getDefaultConfigs
# is the interface up
echo Checking the interface $INTERFACE is up ... 
if ! $IFCONFIG $INTERFACE &> /dev/null 
then
	echo The default interface $INTERFACE is not up, this is a possible problem to investigate
else
	echo Default interface is up
fi
echo 'Checking the interface has an IP ...'
if getInterfaceIP $INTERFACE
then
	echo Interface $INTERFACE has IP $INTERFACEIP
else
	echo Interface $INTERFACE has no IP
fi
echo Checking if we can reach the gateway IP $GATEWAYIP ...
if ! pingCheck $GATEWAYIP
then
	echo Cannot ping Gateway IP $GATEWAYIP
else
	echo We can
fi
