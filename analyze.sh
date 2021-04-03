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
send -- "YOURPASS\r"
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
send -- "YOURPASS\r"
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
