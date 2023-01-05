# knockoff_index

The scripts in this repository aim to generate a positive alpha by proposing an active portfolio strategy. For a thorough introduction see the Wiki tab.

# Warning: 
* All codes and analyses are subject to error.
* All investments are subject to risk. 
* Past performance may not reflective of future gain/losses.
* Provision of the codes and portfolios is not a financial advice.

For enquiries and commercial use, please get in touch via hassannia@outlook.com 

# Replication:

The codes are built on a class structure to simplify backtesting. In order to replicate the backtest results you need to run `backtest_ik.py`. You can fine-tune the specification in the script. 


# Dataset:

– The weekly stock data and indexes are from Refinitiv Eikon. You need an `APP KEY` to access Eikon's API.

– The annual fundamentals are from merged Compustat/CRSP file on WRDS. 

– The risk-free rate and Fama-French factors are also from WRDS. 


# Third-party scripts: 

I) The contents in the R script "knockoffs_matlab" are from @msesia 's GitHub repository providing MATLAB and R codes for the paper entitled "Controlling the False Discovery Rate via Knockoffs” by Barber and  Candès in Annals of Statistics (2015). Warning: Running the scripts may ask for admin priviliges. You do not have to provide that access for running the codes. 

# Access requirement:
To access the data you must have an active subscription with WRDS see (https://wrds-web.wharton.upenn.edu/wrds/). Specifically, you need active subscriptions to CRSP and Compustat schemas on WRDS. To acquire the data you need a functioning JAR driver for MATLAB to access WRDS through Matlab. See https://wrds-www.wharton.upenn.edu/pages/support/programming-wrds/programming-matlab/matlab-from-your-computer/
