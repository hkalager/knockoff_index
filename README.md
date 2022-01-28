# knockoff_index

The scripts in this repository aim to generate a positive alpha by proposing an active portfolio strategy. For more information regarding what you can expect from the codes and the performance, consider reading the Wiki tab.

# Warning: 
* This strategy has a beta greater than 1 in all cases.
* All codes and analyses are subject to error.
* All investments are subject to risk. 
* Past performance may not reflective of future gain/losses.
* Provision of the codes is not a financial advice.

For any enquiries please get in touch via hassannia@outlook.com 

# Replication:

In order to replicate the results you need to run the m files in MATLAB. The steps are identified in file names as "step0_XXX.m", "step1_XXX.m" et cetra. Each file is accompanied by the necessary guidance within the script. In the current format, you need to set the benchmarks for each porfolios seperately. After running the script named "step3_XX.m" you'll get a figure comparing the benchmark excess return vs the knockoff portfolios. 

# Dataset:

– The daily stock data used in this study is from CRSP on WRDS. Once you acquire the account from WRDS you need to enter your username and password into the script "step0_dl_dsf.m" to start collecting the data. 

– The annual fundamentals are from merged Compustat/CRSP file on WRDS. 

– The daily stock indexes closing prices are from Compustat on WRDS. 

– The federal funds rate is from Federal Reserve Board’s H.15 release that contains selected interest rates for U.S. Treasuries and private money market and capital market instruments. All rates are reported in annual terms. Daily figures are for Business days and Monthly figures are averages of Business days unless otherwise noted. The cvs file "Fed_Funds_FRB.csv" contains these rates and is obtained from  https://fred.stlouisfed.org/series/FEDFUNDS


# Third-party scripts: 

I) The contents in the folder "knockoffs_matlab" are from @msesia 's GitHub repository providing MATLAB and R codes for the paper entitled "Controlling the False Discovery Rate via Knockoffs” by Barber and  Candès in Annals of Statistics (2015). Warning: Running the scripts may ask for admin priviliges. You do not have to provide that access for running the codes. 

# Access requirement:
To access the data you must have an active subscription with WRDS see (https://wrds-web.wharton.upenn.edu/wrds/). Specifically, you need active subscriptions to CRSP and Compustat schemas on WRDS. To acquire the data you need a functioning JAR driver for MATLAB to access WRDS through Matlab. See https://wrds-www.wharton.upenn.edu/pages/support/programming-wrds/programming-matlab/matlab-from-your-computer/
