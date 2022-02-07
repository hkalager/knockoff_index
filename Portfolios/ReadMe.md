# Summary
Each csv file corresponds to a proposed portfolio of stocks for going long on the first Friday of the year in the file name and clearing everything on the last Friday of the same year. The files are named as _portfolio_YYYY_RATIO_INDEX.csv_ where:
* YYYY is the calendar year considered. For instance, 2022 means the porfolio is to be invested in on Friday 7th January 2022 and cleared on 29th December 2022. 
* RATIO is the filter rule to shortlist top 50 assets. For instance, btm corresponds to book to market ratio. The btm is calculated as the book value per share (BVPS) from the finalised annual statement for the fiscal year YYYY-2 over last price observed as of the last Friday in year YYYY-1. Considering 2022 portfolios, the BVPSs are from annual statements/10-K reports in fiscal year 2020 and last prices are closing prices on 31st December 2021.
* INDEX is the benchmark/index of choice used by the knockoff regression to audition the shortlisted stocks (top 50 by btm). The index can be either DJIA, S&P 500, or Russell 1000. 

# Columns

* permno: is a unique five-digit permanent identifier assigned by CRSP to each security in the file. Unlike CUSIP, TICKER, and COMNAM, the PERMNO neither changes during an issue's trading history, nor is reassigned after an issue ceases trading. 
* full_name: Company Name.
* Beg_Dat: Begin of Stock Data. 
* gvkey: Global Company Key. This item is a unique identifier and primary key for each company in the Compustat database. 
* sic: 	Standard Industry Classification Code
* industry: SIC code explained
* LastPrice: Last price recorded for the firm as of the last Friday in year YYYY-1. This record comes from CRSP. 
* In_Reduced: Whether the stock in included in the reduced (statistically significant) portfolio. 
* datadate: The fiscal period end date as in Compustat. The date normally corresponds to the fiscal period for YYYY-2. All items after this column are from annual statements. 
* filedate: The datestamp when the company filed a 10-K report with SEC.
* prcc_f: Price Close - Annual - Fiscal. This record is from Compustat and corresponds to the fiscal period ending in column "datadate".
* mkvalt: Market Value - Total - Fiscal. This record is from Compustat and corresponds to the fiscal period ending in column "datadate".
* bkvlps: Book Value Per Share. Book Value Per Share is based on fiscal year-end data and represents Common Equity - Liquidation Value (CEQL) divided by Common Shares Outstanding (CSHO). This record is from Compustat and corresponds to the fiscal period ending in column "datadate".
* epspx: Earnings Per Share (Basic) - Excluding Extraordinary Items. This item represents basic earnings per share before extraordinary items and discontinued operations. This record is from Compustat and corresponds to the fiscal period ending in column "datadate".
* at: Assets - Total. This item represents the total value of assets reported on the Balance Sheet. This record is from Compustat and corresponds to the fiscal period ending in column "datadate".
* ni: Net Income (Loss). In millions. This item represents the income or loss reported by a company after expenses and losses have been subtracted from all revenues and gains for the fiscal period including extraordinary items and discontinued operations. This record is from Compustat and corresponds to the fiscal period ending in column "datadate".
---
* roe: Return on Equity. This is a calculated ratio from figures reported on the Balance Sheet. Calculated as ni (net income) divided over Stockholders' Equity - Total (SEQ). ROE=NI./SEQ. This record is derived from figures on Compustat and corresponds to the fiscal period ending in column "datadate".
* dte: Debt to Equity ratio. This is a calculated ratio from figures reported on the Balance Sheet. Calculated as li (total liablities) divided over Stockholders' Equity - Total (SEQ). dte=LT./SEQ. This record is derived from figures on Compustat and corresponds to the fiscal period ending in column "datadate".
* btm: Book-to-market ratio. This is a calculated ratio from figures reported on the Balance Sheet and market price. Calculated as bkvlps (book value per share) divided over Last Price from CRSP. btm=bkvlps./LastPrice. This record is derived from figures on both Compustat and CRSP. This ratio is as of last Friday in the last calendar year. This ratio assumes no major change in book value per share from "datadate" to last Friday when LastPrice is recorded.  
* etm: Earning-to-market ratio. This is a calculated ratio from figures reported on the Balance Sheet and market price. Calculated as EPSPX (earning per share excluding extraordinary items) divided over Last Price from CRSP. etm=epspx./LastPrice. This record is derived from figures on both Compustat and CRSP. This ratio is as of last Friday in the last calendar year. This ratio assumes no major change in EPSPX per share from "datadate" to last Friday when LastPrice is recorded.  
