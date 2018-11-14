#!/bin/bash


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
