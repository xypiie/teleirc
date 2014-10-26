#!/bin/bash

BOTNAME="teleirc"
CHANNEL="#laupheim"

# open connection to afternet
exec 3<>/dev/tcp/irc.afternet.org/6667
exec 4<>/dev/tcp/localhost/5544

function send_irc {
	echo "SEND: $1"
	echo $1 >&3
}

function send_tele {
	echo "TO_TELE: $1"
	echo $1 >&4
}

while read -r line <&3
do
	echo "GOT: $line"

	if [[ $line =~ ^PING\ : ]]
	then
		send_irc "PONG :${line:6}"
	fi

	rest=$line
	from=${rest%% *}
	rest=${rest#* }
	cmd=${rest%% *}
	rest=${rest#* }
	target=${rest%% *}
	rest=${rest#* }

	echo "from: $from cmd: $cmd target: $target rest: $rest"

	if [[ "$target" == "$BOTNAME" ]]
	then
		if [[ "$cmd" == "005" ]]
		then
			send_irc "JOIN $CHANNEL"
		fi
	elif [[ "$cmd" == "PRIVMSG" && "$target" == "$CHANNEL" ]]
	then
		text=${rest#:}
		echo "--> $text"

		if [[ "$text" =~ ^$BOTNAME:\ *quit ]]
		then
			send_irc "QUIT"
			send_tele "dialog_list"
			break
		elif [[ "$text" =~ ^$BOTNAME: ]]
		then
			to_tele="${from%%!*}: ${text#$BOTNAME:}"
			send_tele "msg @laupheim $to_tele"
		fi
	fi
done &
IRC_PID=$!

while read -r tele_line <&4
do
	echo "GOT TELE: $tele_line"
done &
TELE_PID=$!

send_irc "USER $BOTNAME 0 * :$BOTNAME"
send_irc "NICK $BOTNAME"

wait $IRC_PID
kill $TELE_PID

# close connection to afternet
exec 3<&-
exec 3>&-

# close connection to telegram
exec 4<&-
exec 4>&-

exit
