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
	$PING -q -c 5 -W 2 $1 1> $LOG || return 1
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
	getDefaultLog
	echo Gateway IP $GATEWAYIP
	echo Interface $INTERFACE
	echo System log is $SYSTEMLOG
	return 0
}
getInterfaceIP () {
	commandExists ifconfig || return 1
	INTERFACEIP=$( ifconfig $1 | grep 'inet addr' | awk {'print $2'} | cut -d: -f2 )
	isIPv4 $INTERFACEIP || return 1
	getInterfaceSubnetMask $1
	return 0
}
getInterfaceSubnetMask () {
	commandExists ifconfig || return 1
	SUBNETMASK=$( ifconfig $1 | grep 'inet addr' | awk {'print $4'} | cut -d: -f2 )
	isIPv4 $SUBNETMASK || return 1
	return 0

}
getDefaultLog () {
	for file in /var/log/syslog /var/log/messages
	do
		SYSTEMLOG=$file
		test -f $SYSTEMLOG && return 0
	done
	return 1
}
if pingCheck $EXT_ADDRESS
then 
	pingCheck to external address $EXT_ADDRESS succeeded...exiting
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
