%% Description
% This script generates weekly returns from the daily stock file.
% The script identifies Mondays and then reads the close price for each
% stock listed on CRSP's DSF.
% The script tries to find a csv file with name "dataset_YYYY.csv" where
% YYYY is each calendar year studied and the csv files are produced in 
% the previous step i.e. running the script "step0_dl_dsf"

%% Inputs
% You need to set the study period including the training and testing
% periods. This is done by setting a range for variable "yr_range".

%% Outputs

% An .mat-file with price matrix "prc_mat" for all assets and the list of stocks
% recorded in the variable "stock_list"

%% Credits
% Code developed by Arman Hassanniakalager GitHub @hkalager
% Last reviewed 24 January 2022.

%% Main codes
clear;clc;
delete(gcp('nocreate'));
poolobj=parpool('local',feature('numcores'));
yr_range=[1981:year(now)-1];
for yr=yr_range
    if ~exist(['dataset_',num2str(yr),'.mat'],'file')
        tic;
        tbl1=readtable(['dataset_',num2str(yr),'.csv']);
        tbl1=unique(tbl1);
        fprintf('Dataset downloaded for year %g ...\n',yr);
        tbl1=[tbl1(:,'date'),tbl1(:,'cusip'),tbl1(:,'gvkey'),...
            tbl1(:,'permno'),tbl1(:,'shrout'),...
            tbl1(:,'conm'),tbl1(:,'prc'),tbl1(:,'begdat')];

        tbl1.prc=abs(tbl1.prc);
        tbl1.cap=(tbl1.prc.*tbl1.shrout)/1e3;

        date_list=unique(tbl1.date);
        list_friday=date_list(weekday(date_list)==6);
        first_friday=list_friday(1);
        date_friday=first_friday;
        next_friday=first_friday+calweeks(1);
        while year(next_friday)==year(first_friday)
            date_friday(end+1,1)=next_friday;
            next_friday=next_friday+calweeks(1);
        end
            
        stock_list=unique(tbl1.permno);
        count_friday=numel(date_friday);
        prc_mat=nan(numel(stock_list),count_friday);
        parfor i=1:numel(stock_list)
%             progress_check_100s=mod(i,floor(numel(stock_list)/100));
%             if progress_check_100s==1 && i>1
%                 fprintf('%g%% of processing completed for year %g ...\n',floor(i/floor(numel(stock_list)/100)),yr);
%             end
            selected_asset=stock_list(i);
            
            for t=1:count_friday
                selected_date=date_friday(t);
                idx=find(and(tbl1.date==selected_date,tbl1.permno==selected_asset));
                enough_try=true;
                try_count=0;
                while and(isempty(idx),enough_try)
                    try_count=try_count+1;
                    selected_date=selected_date+caldays(-1);
                    idx=find(and(tbl1.date==selected_date,tbl1.permno==selected_asset));
                    enough_try=try_count<=2;
                end
                if ~isempty(idx)
                    idx=idx(1);
                    p_t=tbl1.prc(idx);
                    prc_mat(i,t)=p_t;
                end
            end
        end

        save(['dataset_',num2str(yr),'.mat']);
        toc;
    else
        fprintf('Dataset already exist for year %g ...\n',yr);
    end
end

delete(poolobj);