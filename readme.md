Broker QIF Converters
======
These scripts are little helpers to convert Hargreaves Lansdown and Interactive Brokers csv statements to a QIF format suitable for importing into Banktivity. This might also work for other programs that accept QIF files as there is nothing specific about the import to Banktivity, but you are on your own.

Only tested in OSX but they should work on any bash version.

##hl2qif
### Intro
HL have gone out of their way to make this as hard as possible. Vital information (commission, ticker) is missing and must be deduced and their internal systems for dealing with foreign shares (everything is reported in Sterling) mean that it messes with Banktivity's systems big time. You will end up with a mess if you try to get quotes for foreign stocks that are created by this method. The only silver lining is that HL are so expensive for this that you should be using someone else anyway.

However, enough can be deduced to make this quicker than entering transactions manually if you have more than a couple of dozen.

The caveats:
- The name (not ticker) of any existing stock in Banktivity _must_ match the HL description. If it doesn't you have to manually fix each trade. This is a real pain after stock splits.
- You must go in afterwards and manually add the ticker of any stock created by the import.
- Transfers between HL accounts and your bank account will not be picked up. If you're lucky Banktivity 6 might automatically X-Match them. Be careful though because it sometime gets false matches.
- You must manually assign the correct category (eg investment income) to dividends after import
- Esoteric corporate actions are not necessarily handled well. If you have some of these and your balance is not correct this is the first place to look.
- I assume you do not keep separate Income and Capital accounts in banktivity so Income to Capital account transfers are ignored. If you do you must create the cases in the script for these transfers, including the names of your accounts. I have not done this.

### The Process

First of all you must manually download the CSVs from HL. If you have more than one it is easier to cat together all the files for one account. eg

```
cat ~/Downloads/portfolio-summary(1).csv > NICKVANTAGE-CAPITAL.csv
cat ~/Downloads/portfolio-summary(2).csv >> NICKVANTAGE-CAPITAL.csv
cat ~/Downloads/portfolio-summary(3).csv >> NICKVANTAGE-CAPITAL.csv
```

(I tend to keep the Capital and Income accounts separate so I can check the stocks before I import the income but you could put them all in one file if you wish.)

If you have existing stocks now is a good time to check their names. Use something like this to get a list of those about to be imported:

`awk -F, {'print $4'} NICKVANTAGE-CAPITAL.csv | sort | uniq`

You then need to manually alter them in Banktivity. Don't worry if they don't exist, they will be created by the import.

Now you can make the qif:

`bash hl2qif.sh NICKVANTAGE-CAPITAL.csv NICKVANTAGE-CAPITAL.qif`

If you get some warnings about lines not matching (possible, there seem to be a myriad of subtle transaction types) you can either add your case in the script (there are basically only two transaction types, Invest or Bank) or ignore them and manually add them later (if you don't do either your account will be wrong!).

Now you need to go add the tickers for any new stocks and make sure the "traded in pence" box is ticked. Also you need to assign the correct income category for any dividends etc.

#ibkr2qif
Not as hard as above but still with some issues:
- You must create a custom statement with only Trades and Dividends in it. Actually you can have whatever you like but trades aren't in the default reports so you must create a custom one whatever.
- The ticker is the only thing available thus you will not get pretty names in your securities only the ticker
- As above you must go in and manually fill in the ticker field if you want banktivity to update it's prices (and for UK stock make sure the traded in pence box is ticked)
- Only Buys, sells and dividends are supported at the moment. A forex trade is assumed to be a transfer between two accounts however I cannot get banktitivty to recognise the counterparty account so they are just deposits and withdrawals presently.
- The name of your dividend income account can be changed at the top of the script.

## Process
Download your custom CSV (see above) then run
`bash ibkr2qif download.csv`
This will create a directory called ```output``` and create a qif file for each currency.
Import these as normal into Banktivity.