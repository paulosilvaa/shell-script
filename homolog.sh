#!/bin/bash
#
# analyze.sh
#
# Author: Paulo Cesar da Silva <p.silva@persisinternet.com.br>
#
# Description: Analisa os logs das OLT's identificando quem e o usuario que caiu.
#
# Releases:
#	10/03/2021 - 1.1 
#	22/02/2021 - 1.2 
#		- Removido comandos cat's desnecessarios.
#		- Remove arquivos temporarios assim que o programa morre
#	23/03/2021
#		- Arrumada a variável que armazena o horário da conexão


# VARIABLES
PIPE="/tmp/pipe-$$"

# FUNCTIONS
usage() {
	echo
	echo "Usage: $0 [Parameters]"
	echo " -i	Specify the IP Address"
	echo
}

log() {
/usr/bin/expect << EOF
spawn telnet $1
expect -exact ">>User name:"
send -- "rafael\r"
expect -exact ">>User password:"
send -- "rgdg712\r"
expect -exact ">"
send -- "display logbuffer\r"
send -- "\r"
send -- " "
send -- " "
send -- " "
send -- " "
send -- " "
send -- " "
send -- "q\r"
send -- "quit\r"
send -- "y\r"
expect eof
EOF
}

login() {
/usr/bin/expect << EOF
spawn telnet $1
expect -exact ">>User name:"
send -- "rafael\r"
expect -exact ">>User password:"
send -- "rgdg712\r"
expect -exact ">"
send -- "enable\r"
expect -exact "#"
send -- "display ont info 0 $parsed\r"
send -- "\r"
send -- "q\r"
send -- "quit\r"
send -- "y\r"
expect eof
EOF
}

kill_process(){
	rm -f $PWD/.$1*.log
	kill 0
}

pipe(){
	if [ ! -p $PIPE ]
	then
		mkfifo $PIPE
	fi
}

listen() {
if [[ $1 =~ ^(([1-9]|[1-9][0-9]|(1[0-9][0-9]|2[0-5][0-5]))\.){3}([1-9]|[1-9][0-9]|(1[0-9][0-9]|2[0-5][0-5]))$ ]]
then
	echo "--- Reading logs ---"
	log $1 > .$1.log

	if [ ! -f /tmp/last ]
	then
        	grep -E '!' $PWD/.$1.log | head -n1 > /tmp/last
		IFS=$'\n'
		client=$(grep -A1 -B1 -E 'The distribute fiber is broken' $PWD/$1.log | grep -Eo '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}|[0-9]{2}-[0-9]{2}-[0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2}|SlotID: [0-9]{1,2}, PortID: [0-9]{1,2}, ONT ID: [0-9]{1,3}' | sed 'N;s/\n/ /' | sed -r 's/(SlotID: [0-9]{1,2}, PortID: [0-9]{1,2}, ONT ID: [0-9]{1,3}) ([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2})/\2 \1/')
	
			for i in $client
			do 
				slot=$(echo $i | sed -r 's/.*(SlotID: [0-9]{1,2}, PortID: [0-9]{1,2}, ONT ID: [0-9]{1,3})/\1/')
				onu=$(echo $i | sed -r 's/.*(SlotID: [0-9]{1,2}, PortID: [0-9]{1,2}, ONT ID: [0-9]{1,3})/\1/')
				parsed=$(echo $onu | sed -r 's/\w+: ([[:digit:]]), \w+: ([[:digit:]]{1,2}), \w+ \w+:/\1 \2/')
				login $1 > .$1-user.log
				username=$(grep -A 25 "display ont info 0 $parsed" $PWD/.$1-user.log | grep "Description" | uniq | awk '{ print $3 }' | sed 's/@.*/@/g')
				time=$(echo $i | sed -r 's/(.*) (SlotID.*)/\1/')

				echo "---------" &> $PIPE
				echo "INFO" &> $PIPE
				echo "Username: $username" &> $PIPE
				echo "ONU: $onu" &> $PIPE
				echo "Time: $time" &> $PIPE
				echo &> $PIPE
			done
	else
        	last=$(cat /tmp/last)
        	first=$(grep -E '!' $PWD/.$1.log| head -n1)
        	sed -i "/$first/,/$last/!d" $PWD/.$1.log
        	grep -E '!' $PWD/.$1.log | head -n1 > /tmp/last

		IFS=$'\n'
		client=$(grep -A1 -B1 -E 'The distribute fiber is broken' $PWD/.$1.log | grep -Eo '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}|[0-9]{2}-[0-9]{2}-[0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2}|SlotID: [0-9]{1,2}, PortID: [0-9]{1,2}, ONT ID: [0-9]{1,3}' | sed 'N;s/\n/ /' | sed -r 's/(SlotID: [0-9]{1,2}, PortID: [0-9]{1,2}, ONT ID: [0-9]{1,3}) ([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2})/\2 \1/')
	
		for i in $client
		do 
			slot=$(echo $i | sed -r 's/.*(SlotID: [0-9]{1,2}, PortID: [0-9]{1,2}, ONT ID: [0-9]{1,3})/\1/')
			onu=$(echo $i | sed -r 's/.*(SlotID: [0-9]{1,2}, PortID: [0-9]{1,2}, ONT ID: [0-9]{1,3})/\1/')
			parsed=$(echo $onu | sed -r 's/\w+: ([[:digit:]]), \w+: ([[:digit:]]{1,2}), \w+ \w+:/\1 \2/')
			login $1 > .$1-user.log
			username=$(grep -A 25 "display ont info 0 $parsed" $PWD/.$1-user.log | grep "Description" | uniq | awk '{ print $3 }' | sed 's/@.*/@/g')
			time=$(echo $i | sed -r 's/(.*) (SlotID.*)/\1/')

				echo "---------" &> $PIPE
				echo "INFO" &> $PIPE
				echo "Username: $username" &> $PIPE
				echo "ONU: $onu" &> $PIPE
				echo "Time: $time" &> $PIPE
				echo &> $PIPE
		done

	fi
else
	echo "IP syntax is wrong... Please validate the IP address!"
fi
}

case $1 in
	-i)
		shift
		pipe
		trap "kill_process" 2
		while true;do listen $1 ; sleep 3;done&
		tail -f $PIPE
		;;
	*)
		usage
		;;
esac
