#! /bin/bash

USAGE="USAGE: $0 INFILE OUTFILE"
INFILE=$1
OUTFILE=$2

if [[ -z $INFILE ]]
then
	echo "Missing arguments"
	echo $USAGE
	exit 1
fi

if [[ -z $OUTFILE ]]
then
	echo "Missing argument"
	echo $USAGE
	exit 2
fi

if [[ ! -e $INFILE ]]
then
	echo "File $INFILE does not exist"
	exit 3
fi

if [[ -e $OUTFILE ]]
then
	echo "File $OUTFILE already exists"
	exit 4
fi

if [[ $INFILE == $OUTFILE ]]
then
	echo "I seriously doubt you want the output file to be the same as the input file"
	echo $USAGE
	exit 5
fi

echo -n "" > $OUTFILE
cat $INFILE | while read line
do

	if [[ ${line:0:1} != "\"" ]]
	then
		continue;
	fi
	
	line_tr=$(echo $line | awk -F'","' {'print $1"|"$2"|"$3"|"$4"|"$5"|"$6"|"$7'} | sed 's/,//g')
	IFS='|'  read DATE_TRADE DATE_SETTLE TX_TYPE DESC UNIT_COST_P UNIT_QTY TOTAL_VALUE_P <<<  "${line_tr:1:${#line_tr}-2}"
	
	# The last 3 words (num  @  num) of the desc are not in the security name.
	# The commission is not supplied and must be calculated from the difference between the TOTAL_VALUE and UNIT_COST*UNIT_QTY
	# Price is in pence

	case "$TX_TYPE" in
		B[0-9]*)
			#buy
			SEC_NAME=$(echo $DESC | sed '$s/ [0-9]* @ [ 0-9\.]*$//')
			UNIT_COST=$(echo "scale=4;$UNIT_COST_P/100" | bc)
			#TOTAL_VALUE=$(echo "scale=4;$TOTAL_VALUE_P/100" | bc)
			TOTAL_VALUE_ABS=$(echo "define abs(x) {if (x<0) {return -x}; return x;}; abs($TOTAL_VALUE_P)" | bc)
			COMM=$(echo "$TOTAL_VALUE_ABS-($UNIT_COST*$UNIT_QTY)" | bc)
			printf "!Type:Invst\nD$DATE_TRADE\nNBuy\nY$SEC_NAME\nI$UNIT_COST\nQ$UNIT_QTY\nC*\nO$COMM\nT$TOTAL_VALUE_ABS\nM$DESC\n^\n" >> $OUTFILE
			;;
		
		S[0-9]*)
			#sell
			SEC_NAME=$(echo $DESC | sed '$s/ [0-9]* @ [ 0-9\.]*$//')
			UNIT_COST=$(echo "scale=4;$UNIT_COST_P/100" | bc)
			#TOTAL_VALUE=$(echo "scale=4;$TOTAL_VALUE_P/100" | bc)
			COMM=$(echo "define abs(x) {if (x<0) {return -x}; return x;};abs(abs($TOTAL_VALUE_P)-($UNIT_COST*$UNIT_QTY))" | bc)
			printf "!Type:Invst\nD$DATE_TRADE\nNSell\nY$SEC_NAME\nI$UNIT_COST\nQ$UNIT_QTY\nC*\nO$COMM\nT$TOTAL_VALUE_P\nM$DESC\n^\n" >> $OUTFILE
			;;
		"MANAGE FEE")
			# HL fees
			printf "!Type:Bank\nD$DATE_TRADE\nT$TOTAL_VALUE_P\nC*\nP$DESC\n^\n" >> $OUTFILE
			;;
		"MAMAGE FEE")
			# HL fees huh? sp?
			printf "!Type:Bank\nD$DATE_TRADE\nT$TOTAL_VALUE_P\nC*\nP$DESC\n^\n" >> $OUTFILE
			;;
		"Transfer")
			# Transfer From Income Account / To Capital Account
			# Don't care. skip
			;;
		"TRANSFER")
			# Internal Product transfer
			# Desc begins "Product Transfer To
			printf "!Type:Bank\nD$DATE_TRADE\nT$TOTAL_VALUE_P\nC*\nP$DESC\n^\n" >> $OUTFILE
			;;
		"INTEREST")
			# Interest Payment
			printf "!Type:Bank\nD$DATE_TRADE\nT$TOTAL_VALUE_P\nC*\nP$DESC\n^\n" >> $OUTFILE
			;;
		"FPD")
			# Account Withdrawal
			printf "!Type:Bank\nD$DATE_TRADE\nT$TOTAL_VALUE_P\nC*\nP$DESC\n^\n" >> $OUTFILE
			;;
		"FPC")
			# Account CRedit
			printf "!Type:Bank\nD$DATE_TRADE\nT$TOTAL_VALUE_P\nC*\nP$DESC\n^\n" >> $OUTFILE
			;;
		"FRC CR")
			# Fractional Credit
			printf "!Type:Bank\nD$DATE_TRADE\nT$TOTAL_VALUE_P\nC*\nP$DESC\n^\n" >> $OUTFILE
			;;
		"SUB DR")
			# Rights Issue Subscription
			printf "!Type:Bank\nD$DATE_TRADE\nT$TOTAL_VALUE_P\nC*\nP$DESC\n^\n" >> $OUTFILE
			;;
		"RDP CR")
			# Redemption Payment
			printf "!Type:Bank\nD$DATE_TRADE\nT$TOTAL_VALUE_P\nC*\nP$DESC\n^\n" >> $OUTFILE
			;;
		[0-9][0-9][0-9][0-9][0-9][0-9])
			#?? Desc = "Vantage Fund Receipt "
			# Account Credit
			printf "!Type:Bank\nD$DATE_TRADE\nT$TOTAL_VALUE_P\nC*\nP$DESC\n^\n" >> $OUTFILE
			;;
		"Card Web")
			#?? Desc = "Vantage Fund Receipt "
			# Account Credit
			printf "!Type:Bank\nD$DATE_TRADE\nT$TOTAL_VALUE_P\nC*\nP$DESC\n^\n" >> $OUTFILE
			;;
		"OVR CR")
			#Overseas Credit
			SEC_NAME=$(echo $DESC | sed '$s/ Overseas Dividend Payment$//')
			printf "!Type:Invst\nD$DATE_TRADE\nNDiv\nY$SEC_NAME\nT$TOTAL_VALUE_P\nM$DESC\n^\n" >> $OUTFILE
			;;
		"ST DIV")
			#Standard Dividend
			SEC_NAME=$(echo $DESC | sed '$s/ Net Dividend Payment$//')
			SEC_NAME=$(echo $SEC_NAME | sed '$s/ Dividend Payment$//')
			printf "!Type:Invst\nD$DATE_TRADE\nNDiv\nY$SEC_NAME\nT$TOTAL_VALUE_P\nM$DESC\n^\n" >> $OUTFILE
			;;
		SP[0-9]*)
			#SiPP contribution claim
			printf "!Type:Bank\nD$DATE_TRADE\nT$TOTAL_VALUE_P\nC*\nP$DESC\n^\n" >> $OUTFILE
			;;
		DRI[0-9]*)
			#Dividend Reinvestment
			printf "!Type:Bank\nD$DATE_TRADE\nT$TOTAL_VALUE_P\nC*\nP$DESC\n^\n" >> $OUTFILE
			;;
		"PDN CR")
			#Property Income
			SEC_NAME=$(echo $DESC | sed '$s/ Net Dividend Payment$//')
			printf "!Type:Invst\nD$DATE_TRADE\nNDiv\nY$SEC_NAME\nT$TOTAL_VALUE_P\nM$DESC\n^\n" >> $OUTFILE
			;;
		"INT CR")
			#Interest income
			SEC_NAME=$(echo $DESC | sed '$s/ Dividend Payment$//')
			printf "!Type:Invst\nD$DATE_TRADE\nNDiv\nY$SEC_NAME\nT$TOTAL_VALUE_P\nM$DESC\n^\n" >> $OUTFILE
			;;
		"CHAPS")
			# Account Withdrawal
			printf "!Type:Bank\nD$DATE_TRADE\nT$TOTAL_VALUE_P\nC*\nP$DESC\n^\n" >> $OUTFILE
			;;
		*)
			echo "NO MATCH! : $TX_TYPE : $line"
			
			;;
	esac
done



