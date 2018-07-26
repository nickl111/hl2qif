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
	#Trades,Header,DataDiscriminator,Asset Category,Currency,Symbol,Date/Time,Exchange,Quantity,T. Price,Proceeds,Comm/Fee,Code
	#Trades,Data,Trade,Stocks,GBP,RCP,"2018-07-20, 08:44:35",CHIXUK,10,21.1,-211,-7.055,P
	#Trades,Data,Trade,Stocks,GBP,RCP,"2018-07-20, 08:44:35",CHIXUK,90,21.1,-1899,-9.495,P
	
	if [[ ${line:0:17} != "Trades,Data,Trade" ]]
	then
		continue;
	fi
	
	line_tr=$(echo $line | awk -F',' {'print $5"|"$6"|"$7"|"$10"|"$11"|"$12"|"$13'} | sed 's/\"//g')
	IFS='|' read CURR TICKER DATE_TRADE UNIT_QTY UNIT_COST TOTAL_VALUE_P COMM <<<  "$line_tr"
	
	if [[ $CURR == 'GBP' ]]
	then
		SEC_NAME=$TICKER.L
	else
		SEC_NAME=$TICKER
	fi

	if [[ $TOTAL_VALUE_P -le 0 ]]
	then
		#buy
		
		#UNIT_COST=$(echo "scale=4;$UNIT_COST_P/100" | bc)
		TOTAL_VALUE_ABS=$(echo "define abs(x) {if (x<0) {return -x}; return x;}; abs($TOTAL_VALUE_P)" | bc)
		COMM_ABS=$(echo "define abs(x) {if (x<0) {return -x}; return x;}; abs($COMM)" | bc)
		printf "!Type:Invst\nD$DATE_TRADE\nNBuy\nY$SEC_NAME\nI$UNIT_COST\nQ$UNIT_QTY\nC*\nO$COMM_ABS\nT$TOTAL_VALUE_ABS\n^\n" >> $OUTFILE
	else
		#sell
		COMM_ABS=$(echo "define abs(x) {if (x<0) {return -x}; return x;}; abs($COMM)" | bc)
		printf "!Type:Invst\nD$DATE_TRADE\nNSell\nY$SEC_NAME\nI$UNIT_COST\nQ$UNIT_QTY\nC*\nO$COMM_ABS\nT$TOTAL_VALUE_P\n^\n" >> $OUTFILE
	
	fi
done



