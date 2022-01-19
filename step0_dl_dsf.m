%% Read Me
% This code is downloading daily price from the Daily Stock File (DSF) in 
% Centre for Research in Security Price (CRSP) for >7000 securities from 
% 1981 to one year before date. In this script, I use the CRSP dataset with
% annual updates added every February. An alternative to acquire more 
% recent data is using "crsp_m_stock" table with monthly updates updated
% 12th business day of each month.

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
% Last reviewed 04-Jan-2022 

%% Make connection to database
try
    driver_=eval('org.postgresql.Driver');
    driver = 'org.postgresql.Driver';
catch
    error('JAR Driver missing ... please see WRDS / MATLAB documentation')
end
dbURL = 'jdbc:postgresql://wrds-pgdata.wharton.upenn.edu:9737/wrds?ssl=require&sslfactory=org.postgresql.ssl.NonValidatingFactory&';
databasename = 'my_wrds';
username = 'armanhs';
password = 'HAJ@rm@n4421';
conn = database(databasename,username,password,driver,dbURL);

gvkey_set=[3,5,8,156758]; % for S&P 500, DJ, NASDAQ, Russel 1000

for yr=1985:year(now)-1
    %% Execute query and fetch results
    if ~exist(['dataset_',num2str(yr),'.csv'],'file')
        disp(['Daily stock file downloading for year ',num2str(yr)])
        tic;
        data = fetch(conn,['SELECT dsf.date, ' ...
        '	dsf.permno, ' ...
        '	dsf.shrout, ' ...
        '	dsfhdr.hcomnam, ' ...
        '	dsf.prc, ' ...
        '	dsfhdr.begdat ' ...
        'FROM ( wrds.crsp.dsf ' ...
        'INNER JOIN wrds.crsp.dsfhdr ' ...
        'ON dsf.cusip = dsfhdr.cusip)  ' ...
        'WHERE dsf.date >= ''' num2str(yr) '-01-01'' ' ...
        '	AND dsf.date < ''' num2str(yr+1) '-01-01''']);
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

%% Execute query and fetch results
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

%% Clear variables
clear conn