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

OUTROOT=`basename $OUTFILE .qif` #remove any .qif suffix
cat $INFILE | while read line
do
	#Trades,Header,DataDiscriminator,Asset Category,Currency,Symbol,Date/Time,Exchange,Quantity,T. Price,Proceeds,Comm/Fee,Code
	#Trades,Data,Trade,Stocks,GBP,RCP,"2018-07-20, 08:44:35",CHIXUK,10,21.1,-211,-7.055,P
	#Trades,Data,Trade,Stocks,GBP,RCP,"2018-07-20, 08:44:35",CHIXUK,90,21.1,-1899,-9.495,P
	
	if [[ ${line:0:17} != "Trades,Data,Trade" ]]
	then
		continue;
	fi
	
	TX_TYPE=${line:18:6}
	
	case "$TX_TYPE" in
		"Stocks")
			line_decomma=$(echo $line | awk -F'"' -v OFS='' '{ for (i=2; i<=NF; i+=2) gsub(",", "", $i) } 1')
			line_tr=$(echo $line_decomma | awk -F',' {'print $5"|"$6"|"$7"|"$9"|"$10"|"$11"|"$12'})
			IFS='|' read CURR TICKER DATE_TRADE UNIT_QTY UNIT_COST TOTAL_VALUE_P COMM <<<  "$line_tr"
			
			if [[ $CURR == 'GBP' ]]
			then
				SEC_NAME=$TICKER.L
			else
				SEC_NAME=$TICKER
			fi
			
			if [[ ${TOTAL_VALUE_P:0:1} == "-" ]]
			then
				#buy
				
				#UNIT_COST=$(echo "scale=4;$UNIT_COST_P/100" | bc)
				TOTAL_VALUE_ABS=$(echo "define abs(x) {if (x<0) {return -x}; return x;}; abs($TOTAL_VALUE_P)" | bc)
				COMM_ABS=$(echo "define abs(x) {if (x<0) {return -x}; return x;}; abs($COMM)" | bc)
				QTY_ABS=$(echo "define abs(x) {if (x<0) {return -x}; return x;}; abs($UNIT_QTY)" | bc)
				printf "!Type:Invst\nD$DATE_TRADE\nNBuy\nY$SEC_NAME\nI$UNIT_COST\nQ$QTY_ABS\nC*\nO$COMM_ABS\nT$TOTAL_VALUE_ABS\n^\n" >> $OUTROOT.$CURR.qif
			else
				#sell
				TOTAL_VALUE_ABS=$(echo "define abs(x) {if (x<0) {return -x}; return x;}; abs($TOTAL_VALUE_P)" | bc)
				COMM_ABS=$(echo "define abs(x) {if (x<0) {return -x}; return x;}; abs($COMM)" | bc)
				QTY_ABS=$(echo "define abs(x) {if (x<0) {return -x}; return x;}; abs($UNIT_QTY)" | bc)
				printf "!Type:Invst\nD$DATE_TRADE\nNSell\nY$SEC_NAME\nI$UNIT_COST\nQ$QTY_ABS\nC*\nO$COMM_ABS\nT$TOTAL_VALUE_P\n^\n" >> $OUTROOT.$CURR.qif
			
			fi
		;;
		"Forex,")
			#Trades,Header,DataDiscriminator,Asset Category,Currency,Symbol,Date/Time,Exchange,Quantity,T. Price,Proceeds,Comm in GBP,Code
			#Trades,Data,Trade,Forex,DKK,GBP.DKK,"2018-08-10, 18:02:57",IDEALFX,0.4126,8.34385,-3.44267251,0
			#Trades,Data,Order,Forex,DKK,GBP.DKK,"2018-08-08, 08:37:07",-,"-25,000",8.2795,206987.5,-1.54574,
			#Trades,Data,Trade,Forex,DKK,GBP.DKK,"2018-08-08, 09:52:16",IDEALFX,"25,002",8.2787,-206984.0574,-1.54574
			
			line_decomma=$(echo $line | awk -F'"' -v OFS='' '{ for (i=2; i<=NF; i+=2) gsub(",", "", $i) } 1')
			line_tr=$(echo $line_decomma | awk -F',' {'print $5"|"$6"|"$7"|"$9"|"$10"|"$11"|"$12'})
			IFS='|' read CURR TICKER DATE_TRADE UNIT_QTY UNIT_COST TOTAL_VALUE_P COMM <<<  "$line_tr"
			
			# TICKER is a currency pair. 1st half is what you are buying, a second what you are paying with
			# - Qty means the opposite
			# One half will always match $CURR (I hope) so we only need the first half. 
			
			PAIR=$(echo $TICKER | awk -F'.' {'print $1'})
			
			if [[ ${TOTAL_VALUE_P:0:1} == "-" ]]
			then
				#buy
				
				#UNIT_COST=$(echo "scale=4;$UNIT_COST_P/100" | bc)
				TOTAL_VALUE_ABS=$(echo "define abs(x) {if (x<0) {return -x}; return x;}; abs($TOTAL_VALUE_P)" | bc)
				COMM_ABS=$(echo "define abs(x) {if (x<0) {return -x}; return x;}; abs($COMM)" | bc)
				QTY_ABS=$(echo "define abs(x) {if (x<0) {return -x}; return x;}; abs($UNIT_QTY)" | bc)
				printf "!Type:Invst\nD$DATE_TRADE\nNXOut\nY$TICKER\nI$UNIT_COST\nQ$QTY_ABS\nC*\nO$COMM_ABS\nT$TOTAL_VALUE_ABS\n^\n" >> $OUTROOT.$CURR.qif
				printf "!Type:Invst\nD$DATE_TRADE\nNXIn\nY$TICKER\nI$UNIT_COST\nQ$TOTAL_VALUE_ABS\nC*\nO$COMM_ABS\nT$QTY_ABS\n^\n" >> $OUTROOT.$PAIR.qif
			else
				#sell
				TOTAL_VALUE_ABS=$(echo "define abs(x) {if (x<0) {return -x}; return x;}; abs($TOTAL_VALUE_P)" | bc)
				COMM_ABS=$(echo "define abs(x) {if (x<0) {return -x}; return x;}; abs($COMM)" | bc)
				QTY_ABS=$(echo "define abs(x) {if (x<0) {return -x}; return x;}; abs($UNIT_QTY)" | bc)
				printf "!Type:Invst\nD$DATE_TRADE\nNXIn\nY$TICKER\nI$UNIT_COST\nQ$QTY_ABS\nC*\nO$COMM_ABS\nT$TOTAL_VALUE_ABS\n^\n" >> $OUTROOT.$CURR.qif
				printf "!Type:Invst\nD$DATE_TRADE\nNXOut\nY$TICKER\nI$UNIT_COST\nQ$TOTAL_VALUE_ABS\nC*\nO$COMM_ABS\nT$QTY_ABS\n^\n" >> $OUTROOT.$PAIR.qif
			
			fi
		;;
	esac
	
done



