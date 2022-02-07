# Summary
Each csv file corresponds to a proposed portfolio of stocks for going long on the first Friday of the year in the file name and clearing everything on the last Friday of the same year. The files are named as _portfolio_YYYY_RATIO_INDEX.csv_ where:
* YYYY is the calendar year considered. For instance, 2022 means the porfolio is to be invested in on Friday 7th January 2022 and cleared on 29th December 2022. 
* RATIO is the filter rule to shortlist top 50 assets. For instance, btm corresponds to book to market ratio. The btm is calculated as the book value per share (BVPS) from the finalised annual statement for the fiscal year YYYY-2 over last price observed as of the last Friday in year YYYY-1. Considering 2022 portfolios, the BVPSs are from annual statements/10-K reports in fiscal year 2020 and last prices are closing prices on 31st December 2021.
* INDEX is the benchmark/index of choice used by the knockoff regression to audition the shortlisted stocks (top 50 by btm). The index can be either DJIA, S&P 500, or Russell 1000. 

# Columns

Coming soon. 
