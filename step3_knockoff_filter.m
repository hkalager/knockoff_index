clear;clc;warning off;
init_knockoffs;
IS_per=10;
Benchmark='Russel_1000';
goal='rmse';
L_cap_count=100; 
results_table=table();
port0_knockoff=[];
port0_reduced=[];
yr_rng=2001:2020;
for yr=yr_rng
    tic;
    load(['dataset_',num2str(yr),'_IS_',num2str(IS_per),'_',Benchmark]);
    Bench_IS_ret=(1+mean(bench_excess_ret))^52-1;
    asset_info_IS=[table(stock_list_IS),asset_info_IS];
    [rho_set,pval_set]=corr(excess_ret_IS,bench_excess_ret);
    sorted_cap=sort(asset_info_IS.cap,'descend');
    L_cap_threshold=sorted_cap(L_cap_count);
    filter_condition=all([asset_info_IS.cap>=L_cap_threshold,...
        all((isnan(excess_ret_IS)==false),1)'],2);
    L_CAP_stocks=asset_info_IS(filter_condition,:);
    fprintf('Year %g: %g qualified large cap (>=USD%gM) stocks\n',yr,size(L_CAP_stocks,1),L_cap_threshold/1e3);
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
    L_CAP_opt=L_CAP_stocks(opt_set,:);
    
    if numel(port0_knockoff)>0
        retention_knockoff=sum(any(L_CAP_opt{:,1}==port0_knockoff,2))/size(L_CAP_opt,1);
    else
        retention_knockoff=0;
    end
    port0_knockoff=L_CAP_opt{:,1}';
    
    
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
    L_CAP_reduced=L_CAP_opt(ind_significant,:);
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
        retention_reduced=sum(any(L_CAP_reduced{:,1}==port0_reduced,2))/size(L_CAP_reduced,1);
    else
        retention_reduced=0;
    end
    port0_reduced=L_CAP_reduced{:,1}';
    
    %% track next year the portfolios
    OOS_db=load(['dataset_',num2str(yr)]);
    oos_stock_prc=OOS_db.prc_mat';
    oos_stock_list=OOS_db.stock_list;
    
    % knockoff portfolios
    oos_knockoff_prc=nan(size(oos_stock_prc,1),numel(L_CAP_opt.stock_list_IS));
    for s=1:numel(L_CAP_opt.stock_list_IS)
        sel_stock=L_CAP_opt.stock_list_IS(s);
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
    oos_knockoff_port_sharpe=sharpe(oos_knockoff_port_ret_ser,0)*(52^.5);
    % equal weight
    w_eq_knock=1/size(L_CAP_opt,1)*ones(size(w_opt));
    oos_knockoff_port_ret_ew=oos_knockoff_ret*w_eq_knock';
    oos_knockoff_port_ret_ser_ew=oos_knockoff_ret_ser*w_eq_knock';
    oos_knockoff_port_ew_sharpe=sharpe(oos_knockoff_port_ret_ser_ew,0)*(52^.5);
    % cap-weight
    w_cw_knock=[L_CAP_opt.cap/sum(L_CAP_opt.cap)]';
    oos_knockoff_port_ret_cw=oos_knockoff_ret*w_cw_knock';
    oos_knockoff_port_ret_ser_cw=oos_knockoff_ret_ser*w_cw_knock';
    oos_knockoff_port_cw_sharpe=sharpe(oos_knockoff_port_ret_ser_cw,0)*(52^.5);
    
    
    % reduced knockoff portfolios
    oos_reduced_prc=nan(size(oos_stock_prc,1),numel(L_CAP_reduced.stock_list_IS));
    for s=1:numel(L_CAP_reduced.stock_list_IS)
        sel_stock=L_CAP_reduced.stock_list_IS(s);
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
    oos_reduced_port_sharpe=sharpe(oos_reduced_port_ret_ser,0)*(52^.5);
    
    %% track the benchmark
    load(['dataset_',num2str(yr),'_IS_',num2str(IS_per),'_',Benchmark],'benchmark_data');
    
    date_ser_OOS=OOS_db.date_monday;
    for s=1:numel(date_ser_OOS)
        idx_bench_prc_OOS=find(benchmark_data.datadate==date_ser_OOS(s));
        bench_prc_OOS(s,1)=benchmark_data.prccd(idx_bench_prc_OOS);
        
    end
    
    oos_bench_ret=bench_prc_OOS(end)/bench_prc_OOS(1)-1;
    oos_bench_ret_ser=price2ret(bench_prc_OOS);
    oos_bench_sharpe=sharpe(oos_bench_ret_ser,0)*(52^.5);
    %% write to the table
    
    results_table{end+1,'Year'}=yr;
    results_table{end,'Cap_threshold_M'}=L_cap_threshold/1e3;
    results_table{end,'Count_Qualifid_LCap'}=size(L_CAP_stocks,1);
    results_table{end,'Count_knockoff'}=size(L_CAP_opt,1);
    results_table{end,'Count_knockoff_reduced'}=size(L_CAP_reduced,1);
    results_table{end,'Retention_knockoff'}=retention_knockoff;
    results_table{end,'Retention_knockoff_reduced'}=retention_reduced;
    results_table{end,[Benchmark,'_IS_ret']}=Bench_IS_ret;
    results_table{end,'knockoff_IS_ret'}=IS_annualised_knockoff;
    results_table{end,'knockoff_reduced_IS_ret'}=IS_annualised_knockoff_red;
    results_table{end,[Benchmark,'_IS_sharpe']}=bench_IS_sharpe;
    results_table{end,'knockoff_IS_sharpe'}=IS_annualised_knockoff_sharpe;
    results_table{end,'knockoff_reduced_IS_sharpe'}=IS_annualised_knockoff_red_sharpe;
    results_table{end,[Benchmark,'_OOS_ret']}=oos_bench_ret;
    results_table{end,'knockoff_OOS_ret'}=oos_knockoff_port_ret;
    results_table{end,'knockoff_ew_OOS_ret'}=oos_knockoff_port_ret_ew;
    results_table{end,'knockoff_cw_OOS_ret'}=oos_knockoff_port_ret_cw;
    results_table{end,'knockoff_reduced_OOS_ret'}=oos_reduced_port_ret;
    results_table{end,[Benchmark,'_OOS_sharpe']}=oos_bench_sharpe;
    results_table{end,'knockoff_OOS_sharpe'}=oos_knockoff_port_sharpe;
    results_table{end,'knockoff_ew_OOS_sharpe'}=oos_knockoff_port_ew_sharpe;
    results_table{end,'knockoff_ew_OOS_sharpe'}=oos_knockoff_port_cw_sharpe;
    results_table{end,'knockoff_reduced_OOS_sharpe'}=oos_reduced_port_sharpe;
    toc;  
end

fprintf(['Average annualized return for ' Benchmark ' is %g%% vs %g%% for knockoff vs %g%% for knockoff-reduced \n'],...
    round(100*mean(results_table{:,[Benchmark,'_OOS_ret']}),2),...
    round(100*mean(results_table.knockoff_OOS_ret),2),...
    round(100*mean(results_table.knockoff_reduced_OOS_ret),2))

writetable(results_table,['Results_top' num2str(L_cap_count) '_' Benchmark '_' goal '.csv']);
figure,
ser_banch=100*[1;cumprod(1+results_table{:,[Benchmark,'_OOS_ret']})];
knockoff_Ser=100*[1;cumprod(1+results_table{:,'knockoff_OOS_ret'})];
knockoff_ew_Ser=100*[1;cumprod(1+results_table{:,'knockoff_ew_OOS_ret'})];
knockoff_cw_Ser=100*[1;cumprod(1+results_table{:,'knockoff_cw_OOS_ret'})];
knockoff_red_Ser=100*[1;cumprod(1+results_table{:,'knockoff_reduced_OOS_ret'})];
x_ser=[yr_rng(1)-1,yr_rng]';
plot(x_ser,ser_banch,'k-x',x_ser,knockoff_Ser,'b-.o',x_ser,knockoff_ew_Ser,'b:+',...
    x_ser,knockoff_cw_Ser,'b--d',x_ser,knockoff_red_Ser,'r--s');
if contains(Benchmark,'_')
    Benchmark(strfind(Benchmark,'_'))='-';
end
legend(Benchmark,'knockoff','knockoff EW','knockoff CW','reduced knockoff','location','northwest')
xlim([x_ser(1),x_ser(end)+1]);
