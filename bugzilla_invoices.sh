#!/bin/bash
#
# Create an invoice or time report for bugzilla clients
# Copyright 2021- AJREPO https://github.com/ajrepo/

CLIENT=""
EMAIL_TO=""
EMAIL_FROM=""
EMAIL_BCC=""
ENDSIGN="AJREPO"
ORGANIZATION="https://github.com/ajrepo/"
MAIL="/usr/bin/mail"
SPACE=' '

# Keep two CRs between Header and html
read -r -d '' MAIL_FORMAT_HEADER<<-ENDTEXT
	MIME-Version: 1.0
	Content-Type: text/html
	Content-Disposition: inline


	<html>
	<body>
	<pre style="font: monospace">
ENDTEXT

MAIL_FORMAT_FOOTER="</pre></body></html>"

SALUTATION="Dear Valued Client,"
SUBJECT="Time Report"

UUID_GEN=$(uuidgen)
MESSAGE_FILE="/tmp/send_invoice.$UUID_GEN.txt"

RATE="234.00"
DISCOUNT_PCT='47.10'

# BASE_DIR can be blank if PROGRAM is in PATH
BASE_DIR="/usr/local/bin/"
PROGRAM="${BASE_DIR}timereport.py"
# TIME_PROGRAM="$PROGRAM $ARGS"
# echo "$TIME_PROGRAM"

NUMBER_OF_VMS=4
PRICE_PER_VM=30.00
HOSTING_TOTAL=$(echo "$NUMBER_OF_VMS * $PRICE_PER_VM" | bc)
HOSTING_LINE=$(printf "%11s:%39s:%11s: $%10s: $%8.2f" 'Hosting  ' "$NUMBER_OF_VMS Virtual Machines in Production   " "$NUMBER_OF_VMS VMs " " $PRICE_PER_VM/vm " "$HOSTING_TOTAL")

function print_v() {
	if [[ $QUIET_MODE == "true" ]]; then
		echo "$1" >> "$MESSAGE_FILE"
	else
		echo "$1" | tee -a "$MESSAGE_FILE"
	fi
}

function usage {
	echo "Usage: $(basename "$0") " 2>&1
	echo 'Call the bugzilla timereport.py program.'
	echo '   -a              Additional arguments to pass to timereports.py (e.g. --begin_date)'
	echo '   -b <EMAIL>      Email to use for BCC: email/report'
	echo '   -c <CLIENT>     Bugzilla Product (client)'
	echo '   -d              Debug Mode: Will also call timereports.py in Debug Mode'
	echo '   -e <ENDSIGN>    The name at the end, the person signing the invoice.'
	echo '   -f <EMAIL>      Email to use for From: email/report'
	echo '   -h              Help (this message)'
	echo '   -i              Call timereports.py in Invoice Mode'
	echo '   -m <number>     Number of (Hosted) Machines (Containers) to charge for'
	echo '   -n              Dry Run. Do not send emails'
	echo '   -o <ORG>        Organization/Company'
	echo '   -p <number>     Percent Discount on Rate per hour'
	echo '   -q              Quiet. Send email only. Do not print to screen'
	echo '   -r <number>     Rate per hour to charge'
	echo '   -s <SALUTATION> The Hello string for reports'
	echo '   -t <EMAIL>      Email to use for To: email/report'
	echo '   -x              Export in Quickbooks IIF format (not yet implemented)'
	echo ''
	echo 'You can use cursor control sequences to get multi-line variables. E.g. '
	# shellcheck disable=SC2028
	echo "   -e $'Your Friend\nAJO' will return a CR in the output of the end signature"
	# shellcheck disable=SC2028
	echo "
	Example: If you are in November and run the following arguments
	$(basename "$0") -r 100 -p 10 -m 10 -i -t client@example.com -c 'Bugzilla Product 1' \\
	-s 'Dear Valued Customer:' -f me@example.com -a '--begin_date=last_month' \\
	-o 'My Example Company' -n -e $'ajotest\nVP of Sales'

	Creates output:

	Dry Run mode is ON No email will be sent.
	Dear Valued Customer:

	Your invoice and details follow:
	------------------------------------------------------------
	Time Summary from 2021-10-01 to 2021-10-31
	------------------------------------------------------------
	#914 : CONFIRMED       : Title from Ticket 914
	#928 : CONFIRMED       : Title from Ticket 928
	     :                 :   which continues on the next line
	#934 : RESOLVED        : Title from Ticket 934
	     :                 :   which continues on the next line
	#935 : RESOLVED        : Title from Ticket 935
	#936 : RESOLVED        : Title from Ticket 936
	     :                 :   which continues on the next line
	------------------------------------------------------------
	   Item    :              Description              : Quantity  :    Rate    :  Amount
	Consulting : Tickets from 2021-10-01 to 2021-10-31 : 15.90 hrs : \$100.00/hr :  \$1590.00
	 Discount  :                                       :           :     10.00% : ($ 159.00)
	  Hosting  :          10 Hosted Service Items      :    10 VMs : $ 30.00/vm : $  300.00
	No charge for research

	TOTAL=\$1731.00

	Thank you for your business, we appreciate it very much

	Sincerely,
	ajotest
	VP of Sales
	My Example Company
	"
	exit 1
}

# Look for @ sign and space for email validation
function check_email() {
	email=$1
	if [[ $email =~ .+@.+ && ! ($email =~ " ") ]] ; then
		return 0
	else
		return 1
	fi
}

# If called without args error out
if [[ ${#} -eq 0 ]]; then
	echo "Must be called with argument specifying client"
	usage
fi


# Define list of arguments expected in the input
optstring=":dinqa:b:c:e:f:h:m:o:p:r:s:t:"
DRY_RUN="false"
BCC="false"
IIF="false"
INVOICE_MODE="false"
QUIET_MODE="false"
PROGRAM_EXTRA_ARGS=""

while getopts ${optstring} arg; do
	#Iterates through args in order of command line, not order of optstring
	case ${arg} in
		a)
			PROGRAM_EXTRA_ARGS="$PROGRAM_EXTRA_ARGS ${OPTARG}"
			;;
		b)
			EMAIL_BCC="${OPTARG}"
			if ! check_email "$EMAIL_BCC"; then
				echo "Error in BCC $EMAIL_BCC"
				exit 1
			fi
			BCC="true"
			;;
		c)
			CLIENT="${OPTARG}"
			;;
		d)
			PROGRAM_EXTRA_ARGS="$PROGRAM_EXTRA_ARGS --debug"
			DEBUG="true"
			echo "Debug mode is ON"
			;;
		e)
			ENDSIGN="${OPTARG}"
			;;
		f)
			EMAIL_FROM="${OPTARG}"
			if ! check_email "$EMAIL_FROM"; then
				echo "Error in FROM $EMAIL_FROM"
				exit 1
			fi
			;;
		i)
			#-w = wrap long lines
			PROGRAM_EXTRA_ARGS="$PROGRAM_EXTRA_ARGS --invoice -w"
			INVOICE_MODE="true"
			SUBJECT="Invoice Number"
			#echo "Invoice mode is ON"
			;;
		q)
			QUIET_MODE='true'
			;;
		m)
			NUMBER_OF_VMS="${OPTARG}"
			if [[ $NUMBER_OF_VMS -lt 0 ]]; then
				echo "Error: Can't have fewer than 0 machines"
				exit 1
			fi
			;;
		n)
			DRY_RUN='true'
			echo "Dry Run mode is ON. No email will be sent"
			;;
		o)
			ORGANIZATION="${OPTARG}"
			;;
		p)
			DISCOUNT_PCT="${OPTARG}"
			if [[ $DISCOUNT_PCT -lt 0 ]]; then
				echo "Error: Can't have percent discount < 0"
				exit 1
			fi
			;;
		r)
			RATE="${OPTARG}"
			if [[ $RATE -lt 0 ]]; then
				echo "Error: Can't have rate less than 0"
				exit 1
			fi
			PROGRAM_EXTRA_ARGS="$PROGRAM_EXTRA_ARGS --rate $RATE"
			;;
		s)
			SALUTATION="${OPTARG}"
			;;
		t)
			EMAIL_TO="${OPTARG}"
			if ! check_email "$EMAIL_TO"; then
				echo "Error in EmailTo $EMAIL_TO"
				exit 1
			fi
			;;
		x)
			IIF="true"
			;;
		:)
			echo "Must supply an argument"
			usage
			;;
		h)
			usage
			;;
		?)
			echo "Invalid option: '${OPTARG}'"
			echo
			usage
			;;
	esac
done

if [[ $CLIENT == "" ]]; then
	echo "Client can not be blank"
	usage
fi

if [[ $DRY_RUN == "false" && ($EMAIL_TO == "" || $EMAIL_FROM == "") ]]; then
	echo "DRY RUN = $DRY_RUN so can't have From or To emails blank"
	usage
fi

if [[ $INVOICE_MODE == "true" ]]; then
	FIRST_LINE="Your invoice and details follow:"
else
	FIRST_LINE="Your time report and details follow:"
fi

if [[ $DEBUG == "true" ]]; then
	echo "DRY RUN = $DRY_RUN"
	echo "DEBUG MODE = $DEBUG"
	echo "PROGRAM_EXTRA_ARGS = $PROGRAM_EXTRA_ARGS"
fi

########################################################
# Generate Outbound message. To/From must be set already
########################################################

# Setup File for outboud mail report
echo "To: <$EMAIL_TO>
Subject: $SUBJECT $UUID_GEN
From: <$EMAIL_FROM>
$MAIL_FORMAT_HEADER

" > "$MESSAGE_FILE"
################################################



read -r -d '' HEADER <<-ENDTEXT
	$SALUTATION
	
	$FIRST_LINE
	
ENDTEXT

if [[ $IIF != "true" ]]; then
	print_v "$HEADER"
fi

# shellcheck disable=SC2086
if TIMEROUT=$($PROGRAM $PROGRAM_EXTRA_ARGS --rate=$RATE --product="$CLIENT"); then
	if [[ $INVOICE_MODE == "true" ]]; then
		BUG_TOTAL=$(echo "$TIMEROUT" | grep Consulting | awk -F: '{print $5}' | sed -e /\ /s/// | sed -e /\\$/s///)
		if [[ $(echo "$DISCOUNT_PCT > 0" | bc) == 1 ]]; then
			DISCOUNT_TOTAL=$(echo "$BUG_TOTAL * $DISCOUNT_PCT * .01" | bc)
			DISCOUNT_LINE=$(printf "%11s:%39s:%11s:%10.2f%% : ($%7.2f)" 'Discount  ' "$SPACE" "$SPACE" "$DISCOUNT_PCT" "$DISCOUNT_TOTAL")
		else
			DISCOUNT_TOTAL=0.00
			DISCOUNT_LINE=""
		fi
		if [[ $(echo "$NUMBER_OF_VMS > 0" | bc) == 1 ]]; then
			HOSTING_TOTAL=$(echo "$NUMBER_OF_VMS * $PRICE_PER_VM" | bc)
			HOSTING_LINE=$(printf "%11s:%39s:%11s: $%10s: $%8.2f" 'Hosting  ' "$NUMBER_OF_VMS Hosted Service Items      " "$NUMBER_OF_VMS VMs " " $PRICE_PER_VM/vm " "$HOSTING_TOTAL")
		else
			HOSTING_TOTAL=0.00
			HOSTING_LINE=""
		fi
		TOTAL=$(echo "$BUG_TOTAL + $HOSTING_TOTAL - $DISCOUNT_TOTAL" | bc)
		read -r -d '' REPORT_LINES<<-ENDTEXT
			$TIMEROUT
			$DISCOUNT_LINE
			$HOSTING_LINE
			No charge for research

			TOTAL=\$$TOTAL
			ENDTEXT
	else
		HOSTING_LINE=""
		DISCOUNT_LINE=""
		REPORT_LINES=$TIMEROUT
	fi
else
	echo "Error in calling $PROGRAM"
	echo "BUG_TOTAL=$BUG_TOTAL"
	exit 1
fi


if [[ $IIF != "true" ]]; then
	#If redirection operator is <<-, then all leading tab characters are stripped
	read -r -d '' FOOTER <<-ENDTEXT
		------------------------------------------------------------
		$REPORT_LINES
		
		Thank you for your business, we appreciate it very much
		
		Sincerely,
		$ENDSIGN
		$ORGANIZATION
	ENDTEXT
	
	print_v "$FOOTER"
fi

echo "$MAIL_FORMAT_FOOTER" >> "$MESSAGE_FILE"

if [[ $DRY_RUN == "false" ]]; then
	if [[ $DEBUG == "true" ]]; then
		echo "SENDING TO $EMAIL_TO"
	fi
	#-t means read FROM, TO, SUBJECT from the header of the message
	$MAIL -t  < "$MESSAGE_FILE"
	if [[ $BCC == "true" && $EMAIL_BCC != "" ]]; then
		$MAIL -s "BCC Invoice $UUID_GEN from JEO.NET" "$EMAIL_BCC" < "$MESSAGE_FILE"
	fi
else
	echo "Dry Run: NO MAIL SENT"
fi

# Note: Must use tabs instead of spaces (e.g. noexpandtab) for heredoc (<<-) to work
# vim: tabstop=2 shiftwidth=2 noexpandtab
