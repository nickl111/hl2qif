#! /bin/bash

USAGE="USAGE: $0 INFILE"
INFILE=$1
OUTFILE="ibkr"
OUTDIR="./output"
DIV_CATEGORY="Investment Income:Dividend Income"


if [[ -z $INFILE ]]
then
	echo "Missing argument"
	echo $USAGE
	exit 1
fi

if [[ ! -e $INFILE ]]
then
	echo "File $INFILE does not exist"
	exit 2
fi

mkdir -p $OUTDIR
if [[ ! -e $OUTDIR ]]
then
	echo "Output directory couldn't be created"
	exit 3
fi

rm -f $OUTDIR/*

OUTROOT="$OUTDIR/$OUTFILE"
cat $INFILE | while read line
do
	#Trades,Header,DataDiscriminator,Asset Category,Currency,Symbol,Date/Time,Exchange,Quantity,T. Price,Proceeds,Comm/Fee,Code
	#Trades,Data,Trade,Stocks,GBP,RCP,"2018-07-20, 08:44:35",CHIXUK,10,21.1,-211,-7.055,P
	#Trades,Data,Trade,Stocks,GBP,RCP,"2018-07-20, 08:44:35",CHIXUK,90,21.1,-1899,-9.495,P
	
	#Dividends,Header,Currency,Date,Description,Amount,Code
	#Dividends,Data,GBP,2018-08-31,SMIF(GG00BJVDZ946) Cash Dividend 0.00500000 GBP per Share (Ordinary Dividend),121.99,
	#Dividends,Data,GBP,2018-09-17,RDSB (GB00B03MM408) Cash Dividend GBP 0.36500000 (Return of Capital),365,
	#Dividends,Data,Total,,,486.99,
	#Dividends,Data,USD,2018-09-04,WMT(US9311421039) Cash Dividend 0.52000000 USD per Share (Ordinary Dividend),216.84,
	#Dividends,Data,USD,2018-09-18,MCD (US5801351017) Cash Dividend USD 1.01000000 (Ordinary Dividend),303,
	#Dividends,Data,Total,,,519.84,
	#Dividends,Data,Total in GBP,,,399.1368828,
	#Dividends,Data,Total Dividends in GBP,,,886.1268828,
	
	case "${line:0:6}" in
		"Divide")
			if [[ ${line:0:15} != "Dividends,Data," ]]
			then
				continue;
			fi
			if [[ ${line:15:5} == "Total" ]]
			then
				continue;
			fi
			line_tr=$(echo $line | awk -F',' {'print $3"|"$4"|"$5"|"$6'})
			IFS='|' read CURR DATE_DIV SEC_DESC TOTAL_VALUE  <<<  "$line_tr"
			
			TICKER=$(echo $SEC_DESC | awk -F"(" {'print $1'} | tr -d '[:space:]')
			
			printf "!Type:Invst\nD$DATE_DIV\nNDiv\nY$TICKER\nP$SEC_DESC\nC*\nT$TOTAL_VALUE\nL$DIV_CATEGORY\n^\n" >> $OUTROOT.$CURR.qif
			
		;;
		"Trades")
	
			if [[ ${line:0:17} != "Trades,Data,Trade" ]]
			then
				continue;
			fi
			
			TX_TYPE=${line:18:6}
			
			case "$TX_TYPE" in
				"Stocks")
					line_decomma=$(echo $line | awk -F'"' -v OFS='' '{ for (i=2; i<=NF; i+=2) gsub(",", "", $i) } 1')
					line_tr=$(echo $line_decomma | awk -F',' {'print $5"|"$6"|"$7"|"$9"|"$10"|"$11"|"$12'})
					IFS='|' read CURR TICKER DATE_TRADE UNIT_QTY UNIT_COST TRADE_VALUE_P COMM <<<  "$line_tr"
					
					if [[ $CURR == 'GBP' ]]
					then
						SEC_NAME=$TICKER.L
					else
						SEC_NAME=$TICKER
					fi
					
					if [[ ${TRADE_VALUE_P:0:1} == "-" ]]
					then
						#buy
						
						#UNIT_COST=$(echo "scale=4;$UNIT_COST_P/100" | bc)
						TRADE_VALUE_ABS=$(echo "define abs(x) {if (x<0) {return -x}; return x;}; abs($TRADE_VALUE_P)" | bc)
						COMM_ABS=$(echo "define abs(x) {if (x<0) {return -x}; return x;}; abs($COMM)" | bc)
						TOTAL_VALUE=$(echo "$TRADE_VALUE_ABS + $COMM_ABS" | bc )
						QTY_ABS=$(echo "define abs(x) {if (x<0) {return -x}; return x;}; abs($UNIT_QTY)" | bc)
						printf "!Type:Invst\nD$DATE_TRADE\nNBuy\nY$SEC_NAME\nI$UNIT_COST\nQ$QTY_ABS\nT$TOTAL_VALUE\nO$COMM\nCc\n^\n" >> $OUTROOT.$CURR.qif
					else
						#sell
						TRADE_VALUE_ABS=$(echo "define abs(x) {if (x<0) {return -x}; return x;}; abs($TRADE_VALUE_P)" | bc)
						COMM_ABS=$(echo "define abs(x) {if (x<0) {return -x}; return x;}; abs($COMM)" | bc)
						TOTAL_VALUE=$(echo "$TRADE_VALUE_ABS - $COMM_ABS" | bc )
						QTY_ABS=$(echo "define abs(x) {if (x<0) {return -x}; return x;}; abs($UNIT_QTY)" | bc)
						printf "!Type:Invst\nD$DATE_TRADE\nNSell\nY$SEC_NAME\nI$UNIT_COST\nQ$QTY_ABS\nT$TOTAL_VALUE\nO$COMM\nCc\n^\n" >> $OUTROOT.$CURR.qif
					
					fi
				;;
				"Forex,")
					#Trades,Header,DataDiscriminator,Asset Category,Currency,Symbol,Date/Time,Exchange,Quantity,T. Price,Proceeds,Comm in GBP,Code
					#Trades,Data,Trade,Forex,DKK,GBP.DKK,"2018-08-10, 18:02:57",IDEALFX,0.4126,8.34385,-3.44267251,0
					#Trades,Data,Order,Forex,DKK,GBP.DKK,"2018-08-08, 08:37:07",-,"-25,000",8.2795,206987.5,-1.54574,
					#Trades,Data,Trade,Forex,DKK,GBP.DKK,"2018-08-08, 09:52:16",IDEALFX,"25,002",8.2787,-206984.0574,-1.54574
					
					line_decomma=$(echo $line | awk -F'"' -v OFS='' '{ for (i=2; i<=NF; i+=2) gsub(",", "", $i) } 1')
					line_tr=$(echo $line_decomma | awk -F',' {'print $5"|"$6"|"$7"|"$9"|"$10"|"$11"|"$12'})
					IFS='|' read CURR TICKER DATE_TRADE UNIT_QTY UNIT_COST TRADE_VALUE_P COMM <<<  "$line_tr"
					
					# TICKER is a currency pair. 1st half is what you are buying, a second what you are paying with
					# - Qty means the opposite
					# One half will always match $CURR (I hope) so we only need the first half. 
					
					PAIR=$(echo $TICKER | awk -F'.' {'print $1'})
					
					if [[ ${TRADE_VALUE_P:0:1} == "-" ]]
					then
						#buy
						
						#UNIT_COST=$(echo "scale=4;$UNIT_COST_P/100" | bc)
						TRADE_VALUE_ABS=$(echo "define abs(x) {if (x<0) {return -x}; return x;}; abs($TRADE_VALUE_P)" | bc)
						COMM_ABS=$(echo "define abs(x) {if (x<0) {return -x}; return x;}; abs($COMM)" | bc)
						QTY_ABS=$(echo "define abs(x) {if (x<0) {return -x}; return x;}; abs($UNIT_QTY)" | bc)
						printf "!Type:Invst\nD$DATE_TRADE\nNXOut\nY$TICKER\nI$UNIT_COST\nQ$QTY_ABS\nC*\nO$COMM_ABS\nT$TRADE_VALUE_ABS\n^\n" >> $OUTROOT.$CURR.qif
						printf "!Type:Invst\nD$DATE_TRADE\nNXIn\nY$TICKER\nI$UNIT_COST\nQ$TRADE_VALUE_ABS\nC*\nO$COMM_ABS\nT$QTY_ABS\n^\n" >> $OUTROOT.$PAIR.qif
					else
						#sell
						TRADE_VALUE_ABS=$(echo "define abs(x) {if (x<0) {return -x}; return x;}; abs($TRADE_VALUE_P)" | bc)
						COMM_ABS=$(echo "define abs(x) {if (x<0) {return -x}; return x;}; abs($COMM)" | bc)
						QTY_ABS=$(echo "define abs(x) {if (x<0) {return -x}; return x;}; abs($UNIT_QTY)" | bc)
						printf "!Type:Invst\nD$DATE_TRADE\nNXIn\nY$TICKER\nI$UNIT_COST\nQ$QTY_ABS\nC*\nO$COMM_ABS\nT$TRADE_VALUE_ABS\n^\n" >> $OUTROOT.$CURR.qif
						printf "!Type:Invst\nD$DATE_TRADE\nNXOut\nY$TICKER\nI$UNIT_COST\nQ$TRADE_VALUE_ABS\nC*\nO$COMM_ABS\nT$QTY_ABS\n^\n" >> $OUTROOT.$PAIR.qif
					
					fi
				;;
			esac
		;;
	esac
done



