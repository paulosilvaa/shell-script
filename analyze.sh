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
#
#
#	Licença: GPL

### Inicializando Variáveis
PIPE="/tmp/pipe-$$"

### FUNCTIONS
usage() {
	echo "Usage: $0 [Parameters]"
	echo "		-i	Specify the IP Address"
	echo "		-h	Print this message"
}

# Coleta logs da OLT
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

# Procura dados do login do cliente com base nas Informações recebidas recebidos da função log().
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

# Remove arquivos temporários
kill_process(){
	rm -f $PWD/.$1*.log
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

listen() {
	# Verifica se a sintaxe do IP que foi passado esta correta
	if [[ $1 =~ ^(([1-9]|[1-9][0-9]|(1[0-9][0-9]|2[0-5][0-5]))\.){3}([1-9]|[1-9][0-9]|(1[0-9][0-9]|2[0-5][0-5]))$ ]]
	then
		echo "--- Reading logs ---"
		log $1 > .$1.log	# Executa função log() para que se possa colectar os logs da OLT e armazena os dados localmente

		if [ ! -f /tmp/last ]
		then
			# Procura pela última linha de log válida e armazena no arquivo /tmp/last(Os logs da OLT são invertidos)
			grep -E '!' $PWD/.$1.log | head -n1 > /tmp/last
			# Defino minha variável $IFS como um \n
			IFS=$'\n'
			# Defindo variavel client com base nas infos do Slot e ONU.
			client=$(grep -A1 -B1 -E 'The distribute fiber is broken' $PWD/$1.log | \
				grep -Eo '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}|[0-9]{2}-[0-9]{2}-[0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2}|SlotID: [0-9]{1,2}, PortID: [0-9]{1,2}, ONT ID: [0-9]{1,3}'|\
				sed 'N;s/\n/ /' | sed -r 's/(SlotID: [0-9]{1,2}, PortID: [0-9]{1,2}, ONT ID: [0-9]{1,3}) ([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2})/\2 \1/')
			for i in $client
			do 
				slot=$(echo $i | sed -r 's/.*(SlotID: [0-9]{1,2}, PortID: [0-9]{1,2}, ONT ID: [0-9]{1,3})/\1/')
				onu=$(echo $i | sed -r 's/.*(SlotID: [0-9]{1,2}, PortID: [0-9]{1,2}, ONT ID: [0-9]{1,3})/\1/')
				parsed=$(echo $onu | sed -r 's/\w+: ([[:digit:]]), \w+: ([[:digit:]]{1,2}), \w+ \w+:/\1 \2/')
				login $1 > .$1-user.log
				username=$(grep -A 25 "display ont info 0 $parsed" $PWD/.$1-user.log | grep "Description" | uniq | awk '{ print $3 }' | sed 's/@.*/@/g')
				time=$(echo $i | sed -r 's/(.*) (SlotID.*)/\1/')

				# Exibe informações e redireciona as mesmas para o arquivo $PIPE
				echo "---------" &> $PIPE
				echo "INFO" &> $PIPE
				echo "Username: $username" &> $PIPE
				echo "ONU: $onu" &> $PIPE
				echo "Time: $time" &> $PIPE
				echo &> $PIPE
			done
		else
			# Inicializa a variável $last com a última linha do log contido em /tmp/last da última passada do for
        		last=$(cat /tmp/last)
			# Inicializa a variável $first com a primeira linha do arquivo atual
        		first=$(grep -E '!' $PWD/.$1.log| head -n1)
			# Deleta linhas repetidas entre o atual e o último arquivo
        		sed -i "/$first/,/$last/!d" $PWD/.$1.log
			# Quando termina, pega novamente a primeira linha e alimenta o arquivo /tmp/last
        		grep -E '!' $PWD/.$1.log | head -n1 > /tmp/last

			# Mesmas funções do primeiro IF
			IFS=$'\n'
			client=$(grep -A1 -B1 -E 'The distribute fiber is broken' $PWD/.$1.log | \
				grep -Eo '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}|[0-9]{2}-[0-9]{2}-[0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2}|SlotID: [0-9]{1,2}, PortID: [0-9]{1,2}, ONT ID: [0-9]{1,3}'|\
				sed 'N;s/\n/ /' | sed -r 's/(SlotID: [0-9]{1,2}, PortID: [0-9]{1,2}, ONT ID: [0-9]{1,3}) ([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2})/\2 \1/')
		
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
	kill_process
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
	-h)
		usage
		;;
	*)
		usage
		;;
esac
