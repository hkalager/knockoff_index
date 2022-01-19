%% Description
% This script generates the training dataset necessary for running the
% knockoff regressions in the next step. For each year in the OOS the
% script finds the past 10 years of data and matches the stock returns,
% with the benchmark, and the risk-free rate (effective federal funds rate)

%% Inputs
% – IS_per= the number of years used for the training/in-sample default is
% 10
% – Benchmark= the index under study e.g. "Russel_1000"; "DJ"; "NASDAQ"; or
% "SP_500". Note: the labels used shall match the labels in script "step0_dl_dsf"
% – oos_range= the out-of-sample trading period for evaluating the performance 

%% Outputs

% An .mat-file with necessary info about the training (IS) and testing
% (OOS) datasets. The file is recorded as
% "dataset_YYYY_IS_IS_per_Benchmark"

%% Credits
% Code developed by Arman Hassanniakalager GitHub @hkalager
% Last reviewed 14 January 2022.

%% Main codes

clear;clc;warning off;
IS_per=15;
Benchmark='DJ';
benchmark_fl_name=['Dataset_Daily_',Benchmark,'.csv'];
benchmark_data=readtable(benchmark_fl_name);
r_f_fl_name='Fed_Funds_FRB.csv';
r_f_tbl=readtable(r_f_fl_name);
r_f_tbl.Properties.VariableNames={'date','FF_O'};
oos_range=2001:2020;
for yr=oos_range
    %% Generating IS data
    fprintf('Generating IS pool for %g ...\n',yr);
    tic;
    benchmark_fl_name=['Dataset_Daily_',Benchmark,'.csv'];
    benchmark_data=readtable(benchmark_fl_name);
    
    stock_list_IS=[];
    prc_mat_IS=[];
    date_ser_IS=[];
    bench_prc_IS=[];
    r_f_IS=[];
    for s=-IS_per:1:-1
        asset_info=table();
        IS_db=load(['dataset_',num2str(yr+s)]);
        curr_tbl1=IS_db.tbl1;
        stock_list_curr=IS_db.stock_list;
        curr_prc_mat=IS_db.prc_mat;
        curr_date_list=IS_db.date_monday;
        for idx_asset=1:numel(stock_list_curr)
            selected_asset=stock_list_curr(idx_asset);
            reg_ind_first=find(curr_tbl1.permno==selected_asset,1,'first');
            reg_age=year(curr_tbl1.date(reg_ind_first))-year(curr_tbl1.begdat(reg_ind_first));
            missing_prc=all(~isnan(curr_prc_mat(idx_asset,:)));
            stock_list_curr(idx_asset,2)=reg_age;
            stock_list_curr(idx_asset,3)=missing_prc;
            asset_info{idx_asset,'cap'}=curr_tbl1.cap(reg_ind_first);
            %asset_info{idx_asset,'ticker'}=curr_tbl1.htsymbol(reg_ind_first);
            asset_info{idx_asset,'full_name'}=curr_tbl1.hcomnam(reg_ind_first);
            asset_info{idx_asset,'Beg_Dat'}=curr_tbl1.begdat(reg_ind_first);
            
        end
        
        idx_list_old=find(stock_list_curr(:,2)>1);
        idx_prc_available=find(stock_list_curr(:,3)==1);
        healthy_assets_idx=ismember(idx_list_old,idx_prc_available);
        healthy_assets=idx_list_old(healthy_assets_idx);
        
        reduced_stock_list=stock_list_curr(healthy_assets,1);
        reduced_prc_mat=curr_prc_mat(healthy_assets,:);
        reduced_asset_info=asset_info(healthy_assets,:);
        
        if numel(stock_list_IS)==0
            stock_list_IS=reduced_stock_list;
            prc_mat_IS=reduced_prc_mat;
            asset_info_IS=reduced_asset_info;
        else
            idx_exist_new_old=ismember(reduced_stock_list,stock_list_IS);
            idx_exist_old_new=ismember(stock_list_IS,reduced_stock_list);
            stock_list_IS=stock_list_IS(ismember(stock_list_IS,reduced_stock_list));
            delisted_stocks_list=find(idx_exist_old_new==0);
            prc_mat_IS=[prc_mat_IS(ismember(stock_list_IS,reduced_stock_list),:),...
            reduced_prc_mat(ismember(reduced_stock_list,stock_list_IS),:)];
            asset_info_IS=reduced_asset_info(idx_exist_new_old,:);
        
        end
        date_ser_IS=[date_ser_IS;curr_date_list];
        
    end
    
    prc_mat_IS=prc_mat_IS';
    ret_IS=price2ret(prc_mat_IS);
    
    for s=1:numel(date_ser_IS)
        idx_bench_prc_IS=find(benchmark_data.datadate==date_ser_IS(s));
        bench_prc_IS(s,1)=benchmark_data.prccd(idx_bench_prc_IS);
        
        idx_r_f_IS=find(r_f_tbl.date==date_ser_IS(s));
        r_f_val=r_f_tbl.FF_O(idx_r_f_IS);
        if isnan(r_f_val)
            r_f_val=r_f_tbl.FF_O(idx_r_f_IS-1);
        end
        r_f_IS(s,1)=r_f_val/100/52;
        
    end
    bench_ret_IS=price2ret(bench_prc_IS);
    
    excess_ret_IS=ret_IS-r_f_IS(1:end-1);
    bench_excess_ret=bench_ret_IS-r_f_IS(1:end-1);
    save(['dataset_',num2str(yr),'_IS_',num2str(IS_per),'_',Benchmark]);
    toc;
    %clear curr_tbl1 IS_db;
end
