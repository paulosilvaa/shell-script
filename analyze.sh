#!/bin/bash
#
# analyze.sh - Analisa logs de OLT's Huawei, identificando o login do user que caiu. 
#	       Esse script foi desenvolvido para auxiliar na identifação de clientes em caixas PON.
#
# Github: https://github.com/paulosilvaa/shell-script
# Autor: Paulo Cesar da Silva <p.silva@persisinternet.com.br>
#
# ------------------------------------------------------------------------
#
#  Releases:
#
#	v1.0 10/03/2021
#		- Versão inicial
#	v1.1 22/02/2021 
#		- Removido comandos cat's desnecessarios
#		- Remove arquivos temporarios assim que o programa morre
#	v1.2 23/03/2021
#		- Arrumada a variável que armazena o horário da conexão
#	v1.3 09/04/2021
#		- Cabeçalho alterado
#		- Comentários adicionados
#		- Resolvido bug da opção "-i"
#		- Melhorada a identação
#	v1.4 09/04/2021
#		- Adicionado parâmetro -h
#		- Adicionado parâmetro -V
#		- Adicionado suporte à mais de 1 parâmetro
#	v1.5 10/04/2021
#		- Adicionado parâmetro -u
#		- Adicionado parâmetro -p
#	v2.0 19/04/201
#		- Script segmentado, separadando as funções que estavam juntas
#		- Paths de arquivos alterados
#		- Adicionado checagem da porta Telnet
#
#
#	Licença: GPL

### Inicializando Variáveis
PIPE="/tmp/pipe-$$"
USER=""
PASS=""
IP=""

### FUNCTIONS
usage() {
	echo
	echo "Usage: $(basename $0) -i 192.168.138.115 -u user -p pass [hV]"
	echo "		-i, --ip	Specify the IP Address"
	echo "		-u, --user	Specify the username"
	echo "		-p, --pass	Specify the password"
	echo "		-h, --help	Print this message"
	echo "		-V, --version	Print the current version"
	echo
}

version(){
	grep -Eo "v[0-9]{1,}\.[0-9]{1,}" $0 | tail -n1
}

# Coleta logs da OLT
log() {
/usr/bin/expect << EOF
spawn telnet $1
expect -exact ">>User name:"
send -- "$USER\r"
expect -exact ">>User password:"
send -- "$PASS\r"
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

# Procura dados do login do cliente com base nas Informações recebidas recebidos da função log().
login() {
/usr/bin/expect << EOF
spawn telnet $1
expect -exact ">>User name:"
send -- "$USER\r"
expect -exact ">>User password:"
send -- "$PASS\r"
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

# Remove arquivos temporários
kill_process(){
	rm -f $PIPE
	kill 0
}

# Função que cria o named pipe
pipe(){
	if [ ! -p $PIPE ]
	then
		mkfifo $PIPE
	fi
}

# Verifica se a sintaxe do IP que foi passado esta correta
validate_ip(){
	if [[ "$1" =~ ^(([1-9]|[1-9][0-9]|(1[0-9][0-9]|2[0-5][0-5]))\.){3}([1-9]|[1-9][0-9]|(1[0-9][0-9]|2[0-5][0-5]))$ ]]
	then
		IP="$1"
	else
		echo "IP syntax is wrong... Please validate the IP address!"
	fi
}

# Faz o parsing dos arquivos
parsing(){
	for cliente in $client
	do
		local LOGUSER="/tmp/"$IP"-user.log"
		local onu=$(echo "$cliente" | sed -r 's/.*(SlotID: [0-9]{1,2}, PortID: [0-9]{1,2}, ONT ID: [0-9]{1,3})/\1/')
		local parsed=$(echo $onu | sed -r 's/\w+: ([[:digit:]]), \w+: ([[:digit:]]{1,2}), \w+ \w+:/\1 \2/')
		login "$IP" > "$LOGUSER"
		local username=$(grep -A 25 "display ont info 0 $parsed" "$LOGUSER" | grep "Description" | uniq | awk '{ print $3 }' | sed 's/@.*/@/g')
		local time=$(echo $cliente | sed -r 's/(.*) (SlotID.*)/\1/')

		# Exibe informações e redireciona as mesmas para o arquivo $PIPE
		echo "---------" &> $PIPE
		echo "INFO" &> $PIPE
		echo "Username: $username" &> $PIPE
		echo "ONU: $onu" &> $PIPE
		echo "Time: $time" &> $PIPE
		echo &> $PIPE
	done
}

# Define variáveis necessárias para o parsing
listen(){
	local LOG="/tmp/"$IP".log"
	echo "--- Reading logs ---"
	log "$IP" > "$LOG" # Executa função log() para que se possa colectar os logs da OLT e armazena os dados localmente

	# Defino minha variável $IFS como um \n
	IFS=$'\n'
	# Defindo variavel client com base nas infos do Slot e ONU.
	local client=$(grep -A1 -B1 -E 'The distribute fiber is broken' "$LOG" | \
	grep -Eo '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}|[0-9]{2}-[0-9]{2}-[0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2}|SlotID: [0-9]{1,2}, PortID: [0-9]{1,2}, ONT ID: [0-9]{1,3}'|\
	sed 'N;s/\n/ /' | sed -r 's/(SlotID: [0-9]{1,2}, PortID: [0-9]{1,2}, ONT ID: [0-9]{1,3}) ([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2})/\2 \1/')

	if [ ! -f /tmp/last ]
	then
		# Procura pela última linha de log válida e armazena no arquivo /tmp/last(Os logs da OLT são invertidos)
		grep -E '!' "$LOG" | head -n1 > /tmp/last
		parsing
	else
		# Inicializa a variável $last com a última linha do log contido em /tmp/last da última passada do for
		local last=$(cat /tmp/last)
		# Inicializa a variável $first com a primeira linha do arquivo atual
		local first=$(grep -E '!' "$LOG" | head -n1)
		# Deleta linhas repetidas entre o atual e o último arquivo
		sed -i "/$first/,/$last/!d" "$LOG"
		# Quando termina, pega novamente a primeira linha e alimenta o arquivo /tmp/last
		grep -E '!' "$LOG" | head -n1 > /tmp/last
		parsing
	fi
}

if [[ -z "$1" ]]
then
	usage
	exit 0
else
	while test -n "$1"
	do
		case $1 in
			-i | --ip)
				shift

				if [ -z "$1" ]
				then
					echo "Missing the IP Address"
				else
					validate_ip "$1"
				fi
				;;
			-u | --user)
				shift
				
				if [ -z "$1" ]
				then
					echo "Missing the name of the username"
				else
					USER="$1"
				fi
				;;
			-p | --pass)
				shift
				
				if [ -z "$1" ]
				then
					echo "Missing the password"
				else
					PASS="$1"
				fi
				;;
			-h | --help)
				usage
				exit 0
				;;
			-V | --version)
				version
				exit 0
				;;
			*)
				usage
				exit 1
				;;
		esac
		shift
	done
fi

if [[ -n "$USER" && -n "$PASS" && -n "$IP" ]]
then
	if nc -w 0.5 -z "$IP" 23
	then
		pipe
		trap "kill_process" 0 2
		while true;do listen;sleep 3;done&
		tail -f $PIPE
	else
		echo "Telnet port is closed"
	fi
else
	usage
	exit 1
fi

