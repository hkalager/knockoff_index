%% Description
% This script conducts the main analysis for evaluating the performance of
% the knockoff portfolios (standard and reduced forms). The script requires
% a training sample (in-sample) as previously constructed by running script
% "step2_XX.m".
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
% Last reviewed 06 February 2022.

%% Main codes

clear;clc;warning off;
init_knockoffs;
IS_per=10;
Benchmark='DJ';
goal='var';
funda_factors={'mkvalt','bkvlps','ni','gp','at','epspx','ebitda',...
    'txt','prcc_f','roe','dte','ebitts'};
filter_rule='btm'; % Any of the above, 'btm', 'etm', or 'roe' as ratios
% of BPS/P, EPS/P, or return on equity

filter_count=50;
funda_tbl=readtable('funda.csv');
funda_tbl.roe=funda_tbl.ni./funda_tbl.seq;
funda_tbl.dte=funda_tbl.lt./funda_tbl.seq;
funda_tbl.ebitts=funda_tbl.ebit./funda_tbl.sale;
company_table=readtable('company_data.csv');
%sic_table=readtable('sic_codes.csv');
r_f_fl_name='Fed_Funds_FRB.csv';
r_f_tbl=readtable(r_f_fl_name);
r_f_tbl.Properties.VariableNames={'date','FF_O'};
dsf_tbl=readtable('dsf_hdr');
results_table=table();
port0_knockoff=[];
port0_reduced=[];
yr_rng=1996:2021;
for yr=yr_rng
    tic;
    load(['dataset_',num2str(yr),'_IS_',num2str(IS_per),'_',Benchmark]);
    Bench_IS_ret=(1+mean(bench_excess_ret,'omitnan'))^52-1;
    asset_info_IS=[table(stock_list_IS),asset_info_IS];
    asset_info_IS.Properties.VariableNames{1}='permno';
    gvkey=zeros(size(asset_info_IS,1),1);
    LastPrice=zeros(size(asset_info_IS,1),1);
    asset_info_IS=[asset_info_IS,table(gvkey,LastPrice)];
    asset_info_IS_add=table();
    for s=1:numel(funda_factors)
        varname=funda_factors{s};
        asset_info_IS_add=[asset_info_IS_add,table(zeros(size(asset_info_IS,1),1),...
            'VariableNames',funda_factors(s))];
    end
    
    parfor s=1:size(asset_info_IS,1)
        asset_permno=asset_info_IS(s,:).permno;
        select_gvkey=unique(curr_tbl1.gvkey(find(curr_tbl1.permno==asset_permno)));
        if numel(select_gvkey)>1
            count_statements=sum(funda_tbl.gvkey==select_gvkey');
            select_gvkey=select_gvkey(count_statements==max(count_statements));
            select_gvkey=select_gvkey(1);
        end
        asset_info_IS(s,:).gvkey=select_gvkey;
        asset_info_IS(s,:).LastPrice=prc_mat_IS(end,s);
        %asset_info_IS{s,'sic'}=company_table.sic(company_table.gvkey==select_gvkey);
        idx_funda=find(all([funda_tbl.fyear==yr-2,...
            funda_tbl.gvkey==select_gvkey'],2),1,'last');
        
        if numel(idx_funda)>0
            asset_info_IS_add(s,:)=funda_tbl(idx_funda,...
                funda_factors);
        end
        
    end
    asset_info_IS=[asset_info_IS,asset_info_IS_add];
    asset_info_IS.btm=asset_info_IS.bkvlps./asset_info_IS.LastPrice;
    asset_info_IS.etm=asset_info_IS.epspx./asset_info_IS.LastPrice;
    shrinkage_merge=sum(asset_info_IS.mkvalt==0)/size(asset_info_IS,1);
    fprintf('Missing %.1f%% of equities by matching to Compustat \n',shrinkage_merge*100)
    [rho_set,pval_set]=corr(excess_ret_IS,bench_excess_ret);
    sorted_measure=sort(asset_info_IS{:,filter_rule},'descend','MissingPlacement','last');
    measure_threshold=sorted_measure(filter_count);
    filter_condition=all([asset_info_IS{:,filter_rule}>=measure_threshold,...
        all((isnan(excess_ret_IS)==false),1)'],2);
    eligible_stocks=asset_info_IS(filter_condition,:);
    fprintf('Year %g: %g qualified equities with %s>=%g \n',yr,size(eligible_stocks,1),filter_rule,measure_threshold);
    X_train=excess_ret_IS(:,filter_condition);
    
    Y_train=bench_excess_ret;
    bench_IS_sharpe=sharpe(Y_train,0)*(52^.5);
    
    opt_set=[];
    fdr_level=.1;
    while isempty(opt_set)
        S = knockoffs.filter(X_train, Y_train,fdr_level,{'fixed'} ,'Randomize',false);
        if numel(S)>0
            opt_set=S;
        else
            fdr_level=fdr_level+.05;
        end
    end
    X_opt=X_train(:,opt_set);
    opt_knockoff_set=eligible_stocks(opt_set,:);
    
    if numel(port0_knockoff)>0
        retention_knockoff=sum(any(opt_knockoff_set{:,1}==port0_knockoff,2))/size(opt_knockoff_set,1);
    else
        retention_knockoff=0;
    end
    port0_knockoff=opt_knockoff_set{:,1}';
    
    %% Optimize knockoffs
    %err_fun=@(w) (mean((X_opt*w'-Y_train).^2))^.5;
    w_0=ones(1,size(X_opt,2))/size(X_opt,2);
    Aeq=ones(size(w_0));
    beq=[1];
    lb= zeros(size(w_0));
    ub= ones(size(w_0));
    options=optimoptions('fmincon','Algorithm','sqp',...
        'Diagnostics','off','Display','off');
    w_opt=fmincon(@(w) error_fun(w,X_opt,Y_train,goal),w_0,[],[],Aeq,beq,lb,ub,[],options);
    port_knockoff=X_opt*w_opt';
    IS_annualised_knockoff=(1+mean(port_knockoff))^52-1;
    IS_annualised_knockoff_sharpe=sharpe(port_knockoff,0)*(52^.5);
    %% knockoff-regress-reduce
    mdl=fitlm(X_opt,Y_train,'Intercept',false);
    ind_significant=find(mdl.Coefficients.pValue<=.1);
    while any(mdl.Coefficients.pValue>.1)
        mdl=fitlm(X_opt(:,ind_significant),Y_train,'Intercept',false);
        ind_significant(mdl.Coefficients.pValue>.1)=[];
    end
    knockoff_set_reduced=opt_knockoff_set(ind_significant,:);
    X_reduced=X_opt(:,ind_significant);
    w0_red=ones(1,size(X_reduced,2))/size(X_reduced,2);
    Aeq_red=ones(size(w0_red));
    beq_red=[1];
    lb_red= zeros(size(w0_red));
    ub_red= ones(size(w0_red));
    
    w_opt_red=fmincon(@(w) error_fun(w,X_reduced,Y_train,goal),w0_red,[],[],...
        Aeq_red,beq_red,lb_red,ub_red,[],options);
    port_knockoff_red=X_reduced*w_opt_red';
    IS_annualised_knockoff_red=(1+mean(port_knockoff_red))^52-1;
    IS_annualised_knockoff_red_sharpe=sharpe(port_knockoff_red,0)*(52^.5);
    
    if numel(port0_reduced)>0
        retention_reduced=sum(any(knockoff_set_reduced{:,1}==port0_reduced,2))/size(knockoff_set_reduced,1);
    else
        retention_reduced=0;
    end
    port0_reduced=knockoff_set_reduced{:,1}';
    
    %% track next year the portfolios
    OOS_db=load(['dataset_',num2str(yr)]);
    oos_stock_prc=OOS_db.prc_mat';
    oos_stock_list=OOS_db.stock_list;
    
    % knockoff portfolios
    oos_knockoff_prc=nan(size(oos_stock_prc,1),numel(opt_knockoff_set.permno));
    for s=1:numel(opt_knockoff_set.permno)
        sel_stock=opt_knockoff_set.permno(s);
        idx_oos_list=find(oos_stock_list==sel_stock);
        if numel(idx_oos_list)>0
            temp_oos_ser=oos_stock_prc(:,idx_oos_list);
            for j=2:numel(temp_oos_ser)
                if isnan(temp_oos_ser(j))
                    temp_oos_ser(j)=temp_oos_ser(j-1);
                end
            end
            oos_knockoff_prc(:,s)=temp_oos_ser;
            
        else
            oos_knockoff_prc(:,s)=ones(size(oos_stock_prc,1),1);
        end
        
    end
    oos_knockoff_ret=oos_knockoff_prc(end,:)./oos_knockoff_prc(1,:)-1;
    oos_knockoff_ret_ser=price2ret(oos_knockoff_prc);
    
    % optimized weights
    oos_knockoff_port_ret=oos_knockoff_ret*w_opt';
    oos_knockoff_port_ret_ser=oos_knockoff_ret_ser*w_opt';
    
    % equal weight
    w_eq_knock=1/size(opt_knockoff_set,1)*ones(size(w_opt));
    oos_knockoff_port_ret_ew=oos_knockoff_ret*w_eq_knock';
    oos_knockoff_port_ret_ser_ew=oos_knockoff_ret_ser*w_eq_knock';
    
    % cap-weight
    w_cw_knock=[opt_knockoff_set.mkvalt/sum(opt_knockoff_set.mkvalt)]';
    oos_knockoff_port_ret_cw=oos_knockoff_ret*w_cw_knock';
    oos_knockoff_port_ret_ser_cw=oos_knockoff_ret_ser*w_cw_knock';
    
    
    % reduced knockoff portfolios
    oos_reduced_prc=nan(size(oos_stock_prc,1),numel(knockoff_set_reduced.permno));
    for s=1:numel(knockoff_set_reduced.permno)
        sel_stock=knockoff_set_reduced.permno(s);
        idx_oos_list=find(oos_stock_list==sel_stock);
        if numel(idx_oos_list)>0
            temp_oos_ser=oos_stock_prc(:,idx_oos_list);
            for j=2:numel(temp_oos_ser)
                if isnan(temp_oos_ser(j))
                    temp_oos_ser(j)=temp_oos_ser(j-1);
                end
            end
            oos_reduced_prc(:,s)=temp_oos_ser;
            
        else
            oos_reduced_prc(:,s)=ones(size(oos_stock_prc,1),1);
        end
        
    end
    oos_reduced_ret=oos_reduced_prc(end,:)./oos_reduced_prc(1,:)-1;
    oos_reduced_port_ret=oos_reduced_ret*w_opt_red';
    
    oos_reduced_ret_ser=price2ret(oos_reduced_prc);
    oos_reduced_port_ret_ser=oos_reduced_ret_ser*w_opt_red';
    
    % equal weight – reduced knockoff
    w_eq_knock_red=1/size(knockoff_set_reduced,1)*ones(size(w_opt_red));
    oos_reduced_port_ret_ew=oos_reduced_ret*w_eq_knock_red';
    oos_reduced_port_ret_ser_ew=oos_reduced_ret_ser*w_eq_knock_red';
    
    
    %% track the benchmark and calculate excess return
    load(['dataset_',num2str(yr),'_IS_',num2str(IS_per),'_',Benchmark],'benchmark_data');
    
    date_ser_OOS=OOS_db.date_friday;
    bench_prc_OOS=[];
    r_f_OOS=[];
    for s=1:numel(date_ser_OOS)
        idx_bench_prc_OOS=find(benchmark_data.datadate<=date_ser_OOS(s),1,'last');
        bench_prc_OOS(s,1)=benchmark_data.prccd(idx_bench_prc_OOS);
        
        idx_r_f_OOS=find(r_f_tbl.date==date_ser_IS(s));
        r_f_val=r_f_tbl.FF_O(idx_r_f_OOS);
        if isnan(r_f_val)
            r_f_val=r_f_tbl.FF_O(idx_r_f_OOS-1);
        end
        r_f_OOS(s,1)=r_f_val/100/52;
    end
    oos_bench_ret=bench_prc_OOS(end)/bench_prc_OOS(1)-1;
    oos_bench_ret_ser=price2ret(bench_prc_OOS);
    
    
    % calculate excess returns
    oos_bench_ret_excess=oos_bench_ret-r_f_OOS(1)*52;
    oos_bench_ret_ser_excess=oos_bench_ret_ser-r_f_OOS(1:end-1);
    oos_bench_sharpe_excess=sharpe(oos_bench_ret_ser_excess,0)*(52^.5);
    
    oos_knockoff_port_ret_excess=oos_knockoff_port_ret-r_f_OOS(1)*52;
    oos_knockoff_port_ret_ser_excess=oos_knockoff_port_ret_ser-r_f_OOS(1:end-1);
    oos_knockoff_port_sharpe_excess=sharpe(oos_knockoff_port_ret_ser_excess,0)*(52^.5);
    
    oos_knockoff_port_ret_ew_excess=oos_knockoff_port_ret_ew-r_f_OOS(1)*52;
    oos_knockoff_port_ret_ser_ew_excess=oos_knockoff_port_ret_ser_ew-r_f_OOS(1:end-1);
    oos_knockoff_port_ew_sharpe_excess=sharpe(oos_knockoff_port_ret_ser_ew_excess,0)*(52^.5);
    
    oos_knockoff_port_ret_cw_excess=oos_knockoff_port_ret_cw-r_f_OOS(1)*52;
    oos_knockoff_port_ret_ser_cw_excess=oos_knockoff_port_ret_ser_cw-r_f_OOS(1:end-1);
    oos_knockoff_port_cw_sharpe_excess=sharpe(oos_knockoff_port_ret_ser_cw_excess,0)*(52^.5);
    
    oos_reduced_port_ret_excess=oos_reduced_port_ret-r_f_OOS(1)*52;
    oos_reduced_port_ret_ser_excess=oos_reduced_port_ret_ser-r_f_OOS(1:end-1);
    oos_reduced_port_sharpe_excess=sharpe(oos_reduced_port_ret_ser_excess,0)*(52^.5);
    
    oos_reduced_port_ret_ew_excess=oos_reduced_port_ret_ew-r_f_OOS(1)*52;
    oos_reduced_port_ret_ser_ew_excess=oos_reduced_port_ret_ser_ew-r_f_OOS(1:end-1);
    oos_reduced_port_ew_sharpe_excess=sharpe(oos_reduced_port_ret_ser_ew_excess,0)*(52^.5);
    
    %% write to the table
    
    results_table{end+1,'Year'}=yr;
    results_table{end,[filter_rule,'_threshold']}=round(measure_threshold,2);
    results_table{end,['Count_Qualifid_',filter_rule]}=size(eligible_stocks,1);
    results_table{end,'Count_knockoff'}=size(opt_knockoff_set,1);
    results_table{end,'Count_knockoff_reduced'}=size(knockoff_set_reduced,1);
    results_table{end,'Retention_knockoff'}=retention_knockoff;
    results_table{end,'Retention_knockoff_reduced'}=retention_reduced;
    results_table{end,[Benchmark,'_IS_ret']}=Bench_IS_ret;
    results_table{end,'knockoff_IS_ret'}=IS_annualised_knockoff;
    results_table{end,'knockoff_reduced_IS_ret'}=IS_annualised_knockoff_red;
    results_table{end,[Benchmark,'_IS_sharpe']}=bench_IS_sharpe;
    results_table{end,'knockoff_IS_sharpe'}=IS_annualised_knockoff_sharpe;
    results_table{end,'knockoff_reduced_IS_sharpe'}=IS_annualised_knockoff_red_sharpe;
    results_table{end,[Benchmark,'_OOS_ret']}=oos_bench_ret_excess;
    results_table{end,'knockoff_OOS_ret'}=oos_knockoff_port_ret_excess;
    results_table{end,'knockoff_ew_OOS_ret'}=oos_knockoff_port_ret_ew_excess;
    results_table{end,'knockoff_cw_OOS_ret'}=oos_knockoff_port_ret_cw_excess;
    results_table{end,'knockoff_reduced_OOS_ret'}=oos_reduced_port_ret_excess;
    results_table{end,'knockoff_ew_reduced_OOS_ret'}=oos_reduced_port_ret_ew_excess;
    results_table{end,[Benchmark,'_OOS_sharpe']}=oos_bench_sharpe_excess;
    results_table{end,'knockoff_OOS_sharpe'}=oos_knockoff_port_sharpe_excess;
    results_table{end,'knockoff_ew_OOS_sharpe'}=oos_knockoff_port_ew_sharpe_excess;
    results_table{end,'knockoff_ew_OOS_sharpe'}=oos_knockoff_port_cw_sharpe_excess;
    results_table{end,'knockoff_reduced_OOS_sharpe'}=oos_reduced_port_sharpe_excess;
    toc;
end

fprintf(['Mean excess annualized return for ' Benchmark ' is %g%% vs %g%% for knockoff vs %g%% for knockoff-reduced \n'],...
    round(100*mean(results_table{:,[Benchmark,'_OOS_ret']}),2),...
    round(100*mean(results_table.knockoff_OOS_ret),2),...
    round(100*mean(results_table.knockoff_reduced_OOS_ret),2))
fprintf('Mean excess annualized return for knockoff-EW is %g%% vs %g%% for EW-knockoff-reduced \n',...
    round(100*mean(results_table.knockoff_ew_OOS_ret),2),...
    round(100*mean(results_table.knockoff_ew_reduced_OOS_ret),2))


writetable(results_table,['Results_top' num2str(filter_count) '_' Benchmark '_' filter_rule '_' goal '.csv']);
figure,
ser_banch=100*[1;cumprod(1+results_table{:,[Benchmark,'_OOS_ret']})];
knockoff_Ser=100*[1;cumprod(1+results_table{:,'knockoff_OOS_ret'})];
knockoff_ew_Ser=100*[1;cumprod(1+results_table{:,'knockoff_ew_OOS_ret'})];
knockoff_cw_Ser=100*[1;cumprod(1+results_table{:,'knockoff_cw_OOS_ret'})];
knockoff_red_Ser=100*[1;cumprod(1+results_table{:,'knockoff_reduced_OOS_ret'})];
knockoff_ew_red_Ser=100*[1;cumprod(1+results_table{:,'knockoff_ew_reduced_OOS_ret'})];
x_ser=[results_table.Year(1)-1;results_table.Year];
plot(x_ser,ser_banch,'k-x',x_ser,knockoff_Ser,'b-.o',x_ser,knockoff_ew_Ser,'b:+',...
    x_ser,knockoff_cw_Ser,'b--d',x_ser,knockoff_red_Ser,'r--s',x_ser,knockoff_ew_red_Ser,'r--+');
if contains(Benchmark,'_')
    Benchmark(strfind(Benchmark,'_'))='-';
end
legend(Benchmark,'knockoff','knockoff EW','knockoff CW','reduced knockoff','reduced knockoff EW','location','northwest')
xlim([x_ser(1),x_ser(end)+1]);