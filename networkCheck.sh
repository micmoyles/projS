#!/bin/bash

# steps, advancing to subsequent step assumes failure
# 1. Can we ping external address (say google DNS 8.8.8.8)
# 2. Is there an external pointing route (default)
# 3. Is host part of the correct subnet? 
# Example - host is 192.add.re.ss but gateway IP for defualt route is 172.add.re.ss then fail
# Is the expected interface up
# 
EXT_ADDRESS='8.8.8.8'
NETSTAT=$( which netstat )
PING=$( which ping )
IP=$( which ip )
TRACEROUTE=$( which traceroute )
ROUTE=$( which route )
IFCONFIG=$( which ifconfig )
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
getDefaultGateway () {
	commandExists netstat || return 1
	GATEWAY=$( $NETSTAT -r | grep default | awk {'print $2'})
	# check gateway matches IP regex
	if ! echo $GATEWAY | egrep -q  "([0-9]{1,3}\.)[0-9]{1,3}"
	then
		echo Cannot determine default Gateway. $GATEWAY is not valid
	fi
}
pingCheck $EXT_ADDRESS && onSuccess pingCheck || echo 'Ping fail, proceeding with checks'  
getDefaultGateway
