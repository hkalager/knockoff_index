%% Read Me
% This script downloads the necessary data files from Compustat and CRSP.

%% Note on CRSP Daily Stock File
% This code is downloading daily price from the Daily Stock File (DSF) in 
% Centre for Research in Security Price (CRSP) for >7000 securities from 
% 1981 to one year before date. In this script, I use the CRSP dataset with
% annual updates added every February. An alternative to acquire more 
% recent data is using "crsp_m_stock" table with monthly updates updated
% 12th business day of each month.

%% Note on Fundamentals from Compustat CRSP merged data by WRDS
% This code is downloading fundamentals from annual financial statements
% from Compustat "funda" file. Only stocks listed wiht exchange codes 11,
% 12, and 14 are considered. Only domestic stocks are considere "popsrc=D".
% All records with missing gross profit or total assets are discarded.
% Records with a negative book value per share are discarded.

%% Note on indexes
% The indexes used in this script are obtained from Compustat on WRDS.
% The choice of DJ, S&P 500, and NASDAQ was to have enough matching
% benchmark for comparing to stocks. Alternative indexes could be
% considered from the csv created named "index_list.csv". 
%   
%% requirements
% 1) To run this code you require access to WRDS dataset at Wharton 
% https://wrds-web.wharton.upenn.edu/ you must enter your username and
% password 
% 2) You need a JAR driver + an JDBC connection as described in
% https://wrds-www.wharton.upenn.edu/pages/support/programming-wrds/programming-matlab/matlab-from-your-computer/

%% Effective federal funds rate
% You can collect the latest Federal Reserve FFR from the address below and 
% store it in file "Fed_Funds_FRB.csv"
% https://fred.stlouisfed.org/series/DFF

% Code developed by Arman Hassanniakalager GitHub @hkalager
% Created 26-Oct-2019 
% Last reviewed 06-Feb-2022 

%% Make connection to database
try
    driver_=eval('org.postgresql.Driver');
    driver = 'org.postgresql.Driver';
catch
    error('JAR Driver missing ... please see WRDS / MATLAB documentation')
end
dbURL = 'jdbc:postgresql://wrds-pgdata.wharton.upenn.edu:9737/wrds?ssl=require&sslfactory=org.postgresql.ssl.NonValidatingFactory&';
databasename = 'my_wrds';
username = 'YOUR_USERNAME';
password = 'YOUR_PASSWORD';
conn = database(databasename,username,password,driver,dbURL);

%% DSF file retrieval

for yr=1980:year(now)-1
    % Execute query and fetch results
    if ~exist(['dataset_',num2str(yr),'.csv'],'file')
        disp(['Daily stock file downloading for year ',num2str(yr)])
        tic;
        query=['SELECT dsf.cusip, ' ...
            '	dsf.permno, ' ...
            '	dsf.date, ' ...
            '	dsf.prc, ' ...
            '	dsf.shrout, ' ...
            '	dsf.hexcd, ' ...
            '	dsfhdr.hcomnam, ' ...
            '	dsfhdr.htsymbol, ' ...
            '	dsfhdr.hshrcd, ' ...
            '	dsfhdr.begdat, ' ...
            '	ccm_lookup.gvkey, ' ...
            '	ccm_lookup.conm, ' ...
            '	ccm_lookup.tic ' ...
            'FROM ( ( wrds.crsp.dsf ' ...
            'INNER JOIN wrds.crsp.dsfhdr ' ...
            'ON dsf.cusip = dsfhdr.cusip)  ' ...
            'INNER JOIN wrds.crsp.ccm_lookup ' ...
            'ON dsfhdr.permno = ccm_lookup.lpermno)  ' ...
            'WHERE dsf.hexcd >= 1 ' ...
            '	AND dsf.hexcd <= 3 ' ...
            '	AND dsf.date >= ''1980-01-01'' ' ...
            '	AND dsfhdr.hshrcd >= 10 ' ...
            '	AND dsfhdr.hshrcd <= 11 ' ...
            '	AND dsf.prc != 0 ' ...
            '   AND dsf.date >= ''' num2str(yr) '-01-01'' ' ...
            '	AND dsf.date < ''' num2str(yr+1) '-01-01''' ...
            'ORDER BY dsf.date ASC'];
        data=fetch(conn,query);
        
        if ~isempty(data)
            writetable(data,['dataset_',num2str(yr),'.csv'])
            disp(['Daily stock file dowloaded for year ',num2str(yr)])
            toc;
        else
            disp(['Empty daily stock file for year ',num2str(yr),'. Try again later'])
        end
        
    else
        disp(['Daily stock file exists for year ',num2str(yr)])
    end
       
end

%%  Get US indexes from Compustat 
gvkey_set=[3,5,8,156758]; % for S&P 500, DJ, NASDAQ, Russel 1000

for gv_code=gvkey_set
    if log10(gv_code)<1
        str_gv=['''00000',num2str(gv_code)];
    elseif log10(gv_code)<2
        str_gv=['''0000',num2str(gv_code)];
    elseif log10(gv_code)<3
        str_gv=['''000',num2str(gv_code)];
    elseif log10(gv_code)<4
        str_gv=['''00',num2str(gv_code)];
    elseif log10(gv_code)<5
        str_gv=['''0',num2str(gv_code)];
    else
        str_gv=['''',num2str(gv_code)];
    end

    query = ['SELECT idx_daily.gvkeyx, ' ...
        '	idx_daily.prccd, ' ...
        '	idx_daily.prchd, ' ...
        '	idx_daily.prcld, ' ...
        '	idx_daily.datadate, ' ...
        '	idx_index.conm, ' ...
        '	idx_index.indexcat, ' ...
        '	idx_index.indexgeo, ' ...
        '	idx_index.indexid, ' ...
        '	idx_index.indextype, ' ...
        '	idx_index.indexval ' ...
        'FROM ( wrds.comp.idx_daily ' ...
        'INNER JOIN wrds.comp.idx_index ' ...
        'ON idx_daily.gvkeyx = idx_index.gvkeyx)  ' ...
        'WHERE idx_daily.gvkeyx =', str_gv,''' ' ...
        'ORDER BY idx_daily.datadate ASC'];

% Execute query and fetch results
    index_data = fetch(conn,query);
    switch gv_code
        case 3
            lbl_index='SP_500';
        case 5
            lbl_index='DJ';
        case 8
            lbl_index='NASDAQ';
        case 152308
            lbl_index='NYSE';
        case 11
            lbl_index='Value_Comp';
        case 88
            lbl_index='Russel_3000';
        case 156758
            lbl_index='Russel_1000';
        otherwise
            lbl_index=['gv_',num2str(gv_code)];
    end
    writetable(index_data,['Dataset_Daily_',lbl_index,'.csv']);
    disp(['Data collected successfully for ',lbl_index]);
end

%% Get a list of available indexes.

idx_query = ['SELECT * ' ...
    'FROM wrds.comp.idx_index'];

idx_data = fetch(conn,idx_query);

writetable(idx_data,'index_list.csv');
disp('Data collected successfully for index list');

%% Get CUSIP info 
if ~exist('hdr_dsf.csv','file')
    hdr_query = ['SELECT * ' ...
    'FROM wrds.crsp.dsfhdr'];
    hdr_data = fetch(conn,hdr_query);
    writetable(hdr_data,'hdr_dsf.csv');
    disp('CUSIP data collected successfully');
    % Execute query and fetch results
    hdr_data = fetch(conn,hdr_query);
    writetable(hdr_data,'dsf_hdr.csv');
else
    disp('Data file already exists for DSF header');
end

%% Compustat annual fundamentals
funda_query =['SELECT funda.cusip, ' ...
    '	funda.gvkey, ' ...
    '	funda.datadate, ' ...
    '	funda.indfmt, ' ...
    '	funda.datafmt, ' ...
    '	funda.popsrc, ' ...
    '	funda.acctstd, ' ...
    '	funda.exchg, ' ...
    '	funda.conm, ' ...
    '	funda.final, ' ...
    '	funda.fyear, ' ...
    '	funda.fyr, ' ...
    '	funda.sich, ' ... Standard Industrial Classification - Historical (SICH)
    '	funda.act, ' ... Current Assets - Total
    '	funda.at, ' ... Assets - Total
    '	funda.bkvlps, ' ... Book Value Per Share
    '	funda.capx, ' ... Capital Expenditures
    '	funda.che, ' ... Cash and Short-Term Investments
    '	funda.csho, ' ... Common Shares Outstanding
    '	funda.cshtr_f, ' ... Common Shares Traded - Annual - Fiscal
    '	funda.dvt, ' ... Dividends - Total
    '	funda.ebit, ' ... Earnings Before Interest and Taxes
    '	funda.ebitda, ' ... Earnings Before Interest, Taxes, Depreciation and Amortization
    '	funda.emp, ' ... Employees
    '	funda.epspx, ' ... Earnings Per Share (Basic) - Excluding Extraordinary Items
    '	funda.gp, ' ... Gross Profit (Loss)
    '	funda.ib, ' ... Income Before Extraordinary Items
    '	funda.lt, ' ... Liabilities - Total (LT)
    '	funda.ni, ' ... Net Income (Loss)
    '	funda.prcc_f, ' ... Price Close - Annual - Fiscal
    '	funda.re, ' ... Retained Earnings
    '	funda.rect, ' ... Receivables - Total
    '	funda.revt, ' ... Revenue - Total
    '	funda.sale, ' ... Sales/Turnover (Net)
    '	funda.seq, ' ... Stockholders' Equity - Total (SEQ)
    '	funda.txt ' ... Income Taxes - Total
    'FROM wrds.comp_na_daily_all.funda ' ...
    'WHERE funda.fyear >= 1980 ' ...
    '	AND funda.final = ''Y'' ' ...
    '	AND funda.exchg >= 11 ' ... New York Stock Exchange (11);
    '	AND funda.exchg <= 14 ' ... NYSE American(12); Nasdaq Stock Market (14)
    '	AND funda.exchg != 13 ' ... NOT OTC Bulletin Board
    '	AND funda.gp != ''NaN'' ' ...
    '	AND funda.at != ''NaN'' ' ...
    '	AND funda.popsrc = ''D'' ' ...
    '	AND funda.prcc_f != ''NaN'' ' ...
    '	AND funda.bkvlps >= 0 ' ...
    'ORDER BY funda.datadate ASC'];

funda_data = fetch(conn,funda_query);
funda_data.mkvalt=funda_data.csho.*funda_data.prcc_f;
disp('Annual Fundamentals data collected successfully');

%% Collect filing data
query_filedata = ['SELECT * ' ...
    'FROM wrds.comp_na_daily_all.co_filedate'];
% Execute query and fetch results
file_data = fetch(conn,query_filedata);

% Now merge into Fundamentals
for s=1:size(funda_data,1)
    sel_datadate=funda_data.datadate(s);
    sel_gv=funda_data.gvkey(s);
    idx_found=find(all([strcmp(file_data.datadate,sel_datadate),...
        strcmp(file_data.gvkey,sel_gv)],2));
    if numel(idx_found)>0
        funda_data{s,'filedate'}=file_data.filedate(idx_found(end));
    end
    
end
funda_data=funda_data(:,[1:3,size(funda_data,2),4:size(funda_data,2)-1]);
writetable(funda_data,'funda.csv');
disp('Annual Fundamentals merged with filing dates successfully');


%% Get company details to extract industry classifications
if ~exist('company_data.csv','file')
    company_query = ['SELECT * ' ...
        'FROM wrds.comp_na_daily_all.company'];

    company_data = fetch(conn,company_query);
    writetable(company_data,'company_data.csv');
    disp('Company information collected successfully');
else
    disp('Company information already exists');
end

%% Get FRB federal funds rate – latest updated record on WRDS March 2020

% frb_query = ['SELECT date, ' ...
%     '	ff_o ' ...
%     'FROM wrds.frb.rates_daily'];
% 
% frb_data = fetch(conn,frb_query);
% 
% writetable(frb_data,'Fed_Funds_FRB.csv');
% disp('Data collected successfully for FRB rate');
%% Close connection to database
close(conn)

%% Old codes department ;) 
% funda_query = ['SELECT cusip, ' ...
%     '	gvkey, ' ...
%     '	indfmt, ' ...
%     '	datafmt, ' ...
%     '	popsrc, ' ...
%     '	acctstd, ' ...
%     '	exchg, ' ...
%     '	conm, ' ...
%     '	datadate, ' ...
%     '	final, ' ...
%     '	fyear, ' ...
%     '   fyr, ' ...
%     '	sich, ' ... % 
%     '	act, ' ... % 
%     '	at, ' ... % 
%     '	bkvlps, ' ... 
%     '	capx, ' ... % 
%     '	che, ' ... % 
%     '	csho, ' ... % 
%     '	cshtr_f, ' ... % 
%     '	dvt, ' ... % 
%     '	ebit, ' ... % 
%     '	ebitda, ' ... % 
%     '	emp, ' ... % 
%     '	epspx, ' ... % 
%     '	gp, ' ... % 
%     '	ib, ' ... % 
%     '   lt, ' ... % 
%     '	ni, ' ... % 
%     '	prcc_f, ' ... % 
%     '	re, ' ... % 
%     '	rect, ' ... % 
%     '	revt, ' ... % 
%     '   sale, '... % 
%     '   seq,  ' ... % 
%     '	txt ' ... % 
%     'FROM wrds.comp_na_daily_all.funda ' ...
%     'WHERE fyear >= 1980 ' ...
%     '	AND final = ''Y'' ' ...
%     '	AND exchg >= 11 ' ... % 
%     '	AND exchg <= 14 ' ... % 
%     '	AND exchg != 13 ' ... % 
%     '	AND gp != ''NaN'' ' ...
%     '	AND at != ''NaN'' ' ...
%     '	AND popsrc = ''D'' ' ...
%     '	AND prcc_f != ''NaN'' ' ...
%     '   AND bkvlps >= 0 ' ...
%     'ORDER BY fyear ASC'];

% data = fetch(conn,['SELECT dsf.date, ' ...
%         '	dsf.permno, ' ...
%         '	dsf.shrout, ' ...
%         '	dsfhdr.hcomnam, ' ...
%         '	dsf.prc, ' ...
%         '	dsfhdr.begdat ' ...
%         'FROM ( wrds.crsp.dsf ' ...
%         'INNER JOIN wrds.crsp.dsfhdr ' ...
%         'ON dsf.cusip = dsfhdr.cusip)  ' ...
%         'WHERE dsf.date >= ''' num2str(yr) '-01-01'' ' ...
%         '	AND dsf.date < ''' num2str(yr+1) '-01-01''']);