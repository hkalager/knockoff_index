

warning('off','all');
init_knockoffs;
IS_per=10;
Benchmark='Russel_1000';
goal='rmse';
L_cap_count=100;
results_table=table();
port0_knockoff=[];
port0_reduced=[];
yr=year(now)-2;

tic;
benchmark_fl_name=['Dataset_Daily_',Benchmark,'.csv'];
benchmark_data=readtable(benchmark_fl_name);
r_f_fl_name='Fed_Funds_FRB.csv';
r_f_tbl=readtable(r_f_fl_name);
r_f_tbl.Properties.VariableNames={'date','FF_O'};

stock_list_IS=[];
prc_mat_IS=[];
date_ser_IS=[];
bench_prc_IS=[];
r_f_IS=[];
for s=-IS_per+1:1:0
    asset_info=table();
    IS_db=load(['dataset_',num2str(yr+s)]);
    curr_tbl1=IS_db.tbl1;
    stock_list_curr=IS_db.stock_list;
    curr_prc_mat=IS_db.prc_mat;
    curr_date_list=IS_db.date_monday;
    for idx_asset=1:numel(stock_list_curr)
        selected_asset=stock_list_curr(idx_asset);
        reg_ind_first=find(curr_tbl1.permno==selected_asset,1,'first');
        reg_ind_last=find(curr_tbl1.permno==selected_asset,1,'last');
        reg_age=year(curr_tbl1.date(reg_ind_first))-year(curr_tbl1.begdat(reg_ind_first));
        missing_prc=all(~isnan(curr_prc_mat(idx_asset,:)));
        stock_list_curr(idx_asset,2)=reg_age;
        stock_list_curr(idx_asset,3)=missing_prc;
        asset_info{idx_asset,'Market_Cap'}=curr_tbl1.cap(reg_ind_first);
        %asset_info{idx_asset,'Ticker'}=curr_tbl1.htsymbol(reg_ind_first);
        asset_info{idx_asset,'Trading_Name'}=curr_tbl1.hcomnam(reg_ind_first);
        asset_info{idx_asset,'Last_Price'}=curr_tbl1.prc(reg_ind_last);
        asset_info{idx_asset,'First_Traded'}=curr_tbl1.begdat(reg_ind_first);
        
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

Bench_IS_ret=(1+mean(bench_excess_ret))^52-1;
asset_info_IS=[table(stock_list_IS,'VariableNames',{'PERMNO'}),asset_info_IS];
[rho_set,pval_set]=corr(excess_ret_IS,bench_excess_ret);
sorted_cap=sort(asset_info_IS.Market_Cap,'descend');
L_cap_threshold=sorted_cap(L_cap_count);
filter_condition=all([asset_info_IS.Market_Cap>=L_cap_threshold,...
    all((isnan(excess_ret_IS)==false),1)'],2);
L_CAP_stocks=asset_info_IS(filter_condition,:);
fprintf('Year %g: %g qualified large cap (>=USD%gM) stocks\n',yr+1,size(L_CAP_stocks,1),L_cap_threshold/1e3);
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

L_CAP_opt=[L_CAP_opt,table(w_opt','VariableNames',{'Optimal_Weight'})];
disp(['The knockoff list with ',num2str(size(L_CAP_opt,1)) ,' stocks is stored in table ''L_CAP_opt''']);
disp(L_CAP_opt);
L_CAP_reduced=[L_CAP_reduced,table(w_opt_red','VariableNames',{'Optimal_Weight'})];
disp(['The knockoff list with ',num2str(size(L_CAP_reduced,1)) ,' stocks is stored in table ''L_CAP_reduced''']);
disp(L_CAP_reduced)
disp('The optimal weights are stored in variables ''w_opt'' and ''w_opt_red'' ...');
