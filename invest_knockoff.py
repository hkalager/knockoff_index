#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Sun Sep 11 12:33:59 2022

@author: Arman Hassanniakalager GitHub: https://github.com/hkalager
Common disclaimers apply. Subject to change at all time.

Last review: 05/01/2023
"""
from datetime import datetime
import numpy as np
import pandas as pd
import statsmodels.api as sm
import warnings
import os
import wrds
import eikon as ek
from time import sleep


warnings.filterwarnings('ignore')

# def cusip_matcher(cusip,matched_cusip):
#     try:
#         matched_cusip8=matched_cusip[matched_cusip['cusip9']==cusip]['cusip8'].iloc[0]
#     except:
#         matched_cusip8='null'
#     return matched_cusip8

class invest_knockoff:
    __version__='0.0.4'
    now=datetime.now()
    def __init__(self, my_wrds_username='armanhs',
                 my_ek_app_key='89da3c58308348ed820fc4604420b5a52e93873e',
                 study_range=range(2002,now.year),look_back=5,verbose=True):
        
        t0=datetime.now()
        
        db=wrds.Connection(wrds_username=my_wrds_username)
        ek.set_app_key(my_ek_app_key)
        self.db=db
        self.ek=ek
        start_yr=study_range[0]
        sql_query=""" select tic, conm, cusip, datadate,datacqtr,fqtr,fyr,
        atq,ltq, cshoq, prccq, epspiq, exchg 
        from comp_na_daily_all.fundq where 
        cshoq is not null and atq is not null and ltq is not null and prccq is not null and
        epspiq is not null and datadate>='"""+str(start_yr-2)+"""-11-01' and
        exchg>10 and exchg<=14 and exchg!=13 and fic='USA' and curcdq='USD'
        order by datadate"""
        tbl_fundq=db.raw_sql(sql_query,date_cols='datadate')
        
        tbl_fundq['bk_val_ps']=(tbl_fundq['atq']-tbl_fundq['ltq'])/tbl_fundq['cshoq']
        tbl_fundq['btm']=tbl_fundq['bk_val_ps']/tbl_fundq['prccq']
        tbl_fundq['mk_val']=tbl_fundq['prccq']*tbl_fundq['cshoq']
        tbl_fundq['E/P']=tbl_fundq['epspiq']/tbl_fundq['prccq']
        
        self.tbl_fundq=tbl_fundq
        
        
        sql_ff="""select dateff, mktrf, smb, hml, umd, rf from ff_all.factors_monthly
        where dateff>='"""+str(start_yr)+"""-01-01' and dateff<'"""+str(study_range[-1]+1)+"""-01-01'
        """
        db_ff=db.raw_sql(sql_ff,date_cols='dateff')
        db_ff['dateff']=[pd.Period(dt,freq='M').end_time.date() for dt in db_ff['dateff']]
        self.db_ff=db_ff
        sql_rf="""select date, rf from ff_all.factors_daily
        where date>='"""+str(start_yr-look_back-1)+"""-12-20'"""
        db_rf=db.raw_sql(sql_rf,date_cols='date').set_index('date')
        day_change=[0]
        [day_change.append((db_rf.index[x]-db_rf.index[x-1]).days) for x in range(1,db_rf.shape[0])]
        db_rf['step']=day_change
        rf_val=[100]
        [rf_val.append(rf_val[-1]*(1+db_rf['rf'].iloc[x]*db_rf['step'].iloc[x])) for x in range(1,db_rf.shape[0])]
        db_rf['level']=rf_val
        self.db_rf=db_rf
        
        
        
        self.look_back=look_back
        self.study_range=study_range
        self.verbose=verbose
        
        t1=datetime.now()
        dt=t1-t0
        if verbose:
            print('data collected successfully from WRDS after '+str(dt.total_seconds())+' seconds')
        
    def backtest(self,approach='value',bench_idx='market',count_top=100,
                 min_cap=50,
                 visualise=True,
                 study_range=None,
                 verbose=None,
                 my_freq='weekly'):
        '''
        

        Parameters
        ----------
        approach : TYPE, optional
            DESCRIPTION. The default is 'value'.
        bench_idx : TYPE, optional
            DESCRIPTION. The default is 'market'.
        count_top : TYPE, optional
            DESCRIPTION. The default is 100.
        min_cap : TYPE, optional
            DESCRIPTION. The default is 50.
        visualise : TYPE, optional
            DESCRIPTION. The default is True.
        study_range : TYPE, optional
            DESCRIPTION. The default is None.
        verbose : TYPE, optional
            DESCRIPTION. The default is None.
        my_freq : TYPE, optional
            DESCRIPTION. The default is 'weekly'.

        Returns
        -------
        None.
        
        CSV files will be recorded. 

        '''
        
        if study_range==None:
            study_range=self.study_range
        if verbose==None:
            verbose=self.verbose

        db=self.db
        ek=self.ek
        look_back=self.look_back
        tbl_fundq=self.tbl_fundq
        db_ff=self.db_ff.copy(deep=True)
        db_rf=self.db_rf.copy(deep=True)
        start_yr=study_range[0]
        
        if bench_idx.lower()=='market' or bench_idx.lower()=='mkrt':
            bench_dl='.TRXFLDUST'
        elif 'sp' in bench_idx.lower() or 's&p' in bench_idx.lower():
            bench_dl='.SP500'
        elif 'val' in bench_idx.lower():
            bench_dl='.RAV'
        elif 'grow' in bench_idx.lower():
            bench_dl='.RAG'
        
        benchmark_df=ek.get_timeseries(bench_dl,
                                         start_date=datetime(start_yr-look_back-1,1,1),
                                         end_date=datetime(study_range[-1]+1,1,1),
                                         fields=['CLOSE'],interval=my_freq)
        
        
        if count_top<50:
            over_count_factor=2.5
        else:
            over_count_factor=2
        
        port_ret=[]
        port_ser=pd.DataFrame()

        knockoff_ret=[]
        knockoff_ser=pd.DataFrame()
        wls_ret=[]
        wls_ser=pd.DataFrame()

        bench_ret=[]
        count_considered=[]
        count_knockoff=[]
        count_wls=[]
        missing_set=[]

        for yr in study_range:
            t00=datetime.now()
            mini_tbl=tbl_fundq[tbl_fundq['datadate']<=datetime(yr-1,11,15)]\
                        [tbl_fundq['datadate']>datetime(yr-2,11,15)]\
                            [tbl_fundq['mk_val']>(min_cap)]
            
            if verbose:
                print('dropping companies with less than 4 quarterly reports')
            mini_tbl['report count']=[mini_tbl[mini_tbl['cusip']==cusip].shape[0] for cusip in mini_tbl['cusip']]
            mini_tbl=mini_tbl[mini_tbl['report count']==4]
            mini_tbl=mini_tbl.sort_values(by=['cusip','datadate'],ascending=True,ignore_index=True)
            mini_tbl=mini_tbl[mini_tbl.index%4==3]
            
            if 'val' in approach:
                mini_tbl=mini_tbl.sort_values(by='btm',ascending=False,ignore_index=True)
            elif 'grow' in approach:
                mini_tbl=mini_tbl.sort_values(by='E/P',ascending=False,ignore_index=True)
            elif 'cap' in approach:
                mini_tbl=mini_tbl.sort_values(by='mk_val',ascending=False,ignore_index=True)
            
            mini_tbl=mini_tbl.iloc[:int(count_top*over_count_factor)]
            
            if verbose:
                print('collecting RICs from Eikon...')


            rics=[]
            iterr=0
            for idx in range(0,mini_tbl.shape[0]):
                print('iteration: '+ str(iterr)+'... ')
                cusip=mini_tbl['cusip'].iloc[idx]
                ticker=mini_tbl['tic'].iloc[idx]
                iterr+=1
                t0_0=datetime.now()
                try:
                    matched_RICs=ek.get_symbology(cusip,from_symbol_type='cusip',to_symbol_type='ric',best_match=False)['RICs'].iloc[0]
                    matched_ric=matched_RICs[0]
                    print('Matching via CUSIP successful for '+ticker+', matched RIC: '+matched_ric+' out of '+str(len(matched_RICs))+' choices')
                except:
                    print('Matching via CUSIP failed for '+ticker)
                    sleep(.5)
                    t0_0=datetime.now()
                    try:
                        matched_RICs=ek.get_symbology(ticker,from_symbol_type='ticker',to_symbol_type='ric',best_match=False)['RICs'].iloc[0]
                        matched_ric=[ric for ric in matched_RICs if (ticker+'.') in ric][0]
                        print('Matching via ticker successful for '+ticker+', matched RIC: '+matched_ric+' out of '+str(len(matched_RICs))+' choices')
                    except:
                        print('Matching via ticker failed for '+ticker)
                        matched_ric='null'
                
                rics.append(matched_ric)
                t0_1=datetime.now()
                dt=(t0_1-t0_0).total_seconds()
                if dt<0.5:
                    sleep(0.5)
            mini_tbl['ric']=rics
            
            mini_tbl=mini_tbl[mini_tbl['ric']!='null'].reset_index(drop=True)
            unique_ric=[((mini_tbl.iloc[:idx][mini_tbl['ric']==mini_tbl.iloc[idx]['ric']]).shape[0]==0) for idx in mini_tbl.index]
            mini_tbl=mini_tbl[unique_ric].reset_index(drop=True)
            
            try:
                tbl_ek_last=ek.get_timeseries(mini_tbl['ric'].to_list(),
                                              start_date=datetime(yr-1,12,1),end_date=datetime(yr+1,1,1),
                                              fields=['CLOSE'],interval='monthly')
            except:
                sleep(60)
                tbl_ek_last=ek.get_timeseries(mini_tbl['ric'].to_list(),
                                              start_date=datetime(yr-1,12,1),end_date=datetime(yr+1,1,1),
                                              fields=['CLOSE'],interval='monthly')
            

            last_price=np.zeros_like(mini_tbl['ric'])
            last_price_oos=np.zeros_like(mini_tbl['ric'])
            for s in range(0,mini_tbl.shape[0]):
                ric=mini_tbl['ric'].iloc[s]
                if ric in tbl_ek_last:
                    prices_ric=tbl_ek_last[ric]
                    if len(prices_ric.shape)>1:
                        prices_ric=prices_ric.iloc[:,0]
                    prices_valid_ric=prices_ric[pd.isna(prices_ric)==False]
                    
                    if prices_valid_ric.shape[0]>1:
                        last_price[s]=prices_valid_ric.iloc[0]
                        last_price_oos[s]=prices_valid_ric.iloc[-1]
            
            mini_tbl['last price']=last_price
            mini_tbl['last price OOS']=last_price_oos
            mini_tbl= mini_tbl[mini_tbl['last price']!=0]
            mini_tbl['btm']=mini_tbl['bk_val_ps']/mini_tbl['last price']
            mini_tbl['P/E']=mini_tbl['last price']/mini_tbl['epspiq']
            mini_tbl['mk_val']=mini_tbl['last price']*mini_tbl['cshoq']
            
            
            if 'val' in approach:
                mini_tbl=mini_tbl.sort_values(by='btm',ascending=False,ignore_index=True)
            elif 'grow' in approach:
                mini_tbl=mini_tbl.sort_values(by='E/P',ascending=False,ignore_index=True)
            elif 'cap' in approach:
                mini_tbl=mini_tbl.sort_values(by='mk_val',ascending=False,ignore_index=True)
            
            benchmark_is=benchmark_df[np.logical_and(benchmark_df.index>=datetime(yr-look_back-1,12,25),
                                                     benchmark_df.index<=datetime(yr,1,1))]
            benchmark_is['return']=(benchmark_is['CLOSE']/benchmark_is['CLOSE'].shift(1))-1
            idx_is=benchmark_is.index
            # benchmark_is=benchmark_df_d[np.logical_and(benchmark_df_d.index>=datetime(yr-look_back-1,12,25),benchmark_df_d.index<datetime(yr,1,1))]
            # idx_is=benchmark_is.index
            # if any([bench_idx.lower()=='market','sp' in bench_idx.lower(),'s&p' in bench_idx.lower()]):
            #     index_level=[float(100)]
            #     __=[index_level.append(index_level[-1]*(1+chng)) for chng in benchmark_is.iloc[1:]]
            #     benchmark_is=pd.DataFrame(data=benchmark_is)
            #     benchmark_is['level']=index_level
            # else:
            #     benchmark_is=pd.DataFrame(data=benchmark_is)
            #     benchmark_is.columns=['level']
                
            
            tbl_ek_is_ser=ek.get_timeseries(mini_tbl['ric'].to_list(),
                                            start_date=datetime(yr-look_back-1,1,1),
                                            end_date=datetime(yr,1,1),
                                            fields=['CLOSE'],interval=my_freq)
            val_idx=[np.sum(pd.isna(tbl_ek_is_ser.iloc[idx,:]))<
                     .25*tbl_ek_is_ser.shape[0] for idx in range(tbl_ek_is_ser.shape[0])]
            
            tbl_ek_is_ser=tbl_ek_is_ser.loc[val_idx]
            is_iter=0
            while all([np.min(tbl_ek_is_ser.index)>np.min(benchmark_is.index),is_iter<10]) :
                is_iter+=1
                print('getting more data iteration '+str(is_iter)+'...')
                sleep(.5)
                new_end=(pd.Period(np.min(tbl_ek_is_ser.index),freq='M').start_time).date()
                try:
                    tbl_ek_new=ek.get_timeseries(mini_tbl['ric'].to_list(),
                                                start_date=datetime(yr-look_back-1,12,25),
                                                end_date=str(new_end),
                                                fields=['CLOSE'],interval=my_freq)
                except:
                    print('problem with data ... retry after 1 second')
                    sleep(1)
                
                tbl_ek_is_ser=tbl_ek_is_ser.append(tbl_ek_new).sort_index()
                val_idx=[np.sum(pd.isna(tbl_ek_is_ser.iloc[idx,:]))<
                         .25*tbl_ek_is_ser.shape[0] for idx in range(tbl_ek_is_ser.shape[0])]
                tbl_ek_is_ser=tbl_ek_is_ser.loc[val_idx]
            
            for col in tbl_ek_is_ser.columns:
                if np.sum(pd.isna(tbl_ek_is_ser[col]))>.25*tbl_ek_is_ser.shape[0]:
                    tbl_ek_is_ser=tbl_ek_is_ser.drop(columns=col)
            
            missing_set.append(int(count_top*over_count_factor)-tbl_ek_is_ser.shape[-1])
            print('missing '+str(missing_set[-1])+' out of '+str(int(count_top*over_count_factor))+' top '+approach)
            
            missing_assets=[asset for asset in mini_tbl['ric'] if (asset not in tbl_ek_is_ser.columns)]
            for asset in missing_assets:
                mini_tbl=mini_tbl.drop(index=mini_tbl[mini_tbl['ric']==asset].index)
            
            mini_tbl=mini_tbl.iloc[:count_top]
            tbl_ek_is_ser=tbl_ek_is_ser.iloc[:,:count_top]
            
            # count_considered.append(tbl_crs_matrix.shape[-1])
            # print('Considered '+str(count_considered[-1])+' out of '+str(int(count_top*over_count_factor))+' top '+approach)    
            
            
            matching_rf=pd.DataFrame(index=tbl_ek_is_ser.index,columns=['level'])
            for i in range(matching_rf.shape[0]):
                matching_rf['level'].iloc[i]=db_rf[db_rf.index<=matching_rf.index[i]]['level'][-1]
            
            
            
            X_ret=(tbl_ek_is_ser/tbl_ek_is_ser.shift(1))-1
            rf_ret=matching_rf['level']/matching_rf.shift(1)['level']-1
            
            for col in X_ret.columns:
                vals=X_ret[col]-rf_ret
                vals[pd.isna(vals)]=0
                X_ret[col]=vals.astype(float)
            
            Y_ret=benchmark_is[np.isin(benchmark_is.index,X_ret.index)]
            
            Y_ret['return']=Y_ret['return']-rf_ret
            Y_ret.pop('CLOSE')
            
            X_ret=X_ret[1:]
            Y_ret=Y_ret[1:]
            
            X_ret.to_csv('X_ser.csv')
            Y_ret.to_csv('Y_ser.csv')
            __=os.system('Rscript knockoff_script.R')
            last_edit_result=datetime.fromtimestamp(os.path.getmtime('selected_knockoffs.csv'))
            last_edit_y=datetime.fromtimestamp(os.path.getmtime('Y_ser.csv'))
            if last_edit_result>last_edit_y:
                selected_cols_knockoff=pd.read_csv('selected_knockoffs.csv')
                selected_knockoff=[X_ret.columns[selected_cols_knockoff[col].iloc[0]-1] for col in selected_cols_knockoff.columns]
            else:
                selected_knockoff=[col for col in X_ret.columns]
            
            y_regress=np.asarray(Y_ret['return'],dtype=float)
            weights=(y_regress**2)/np.sum(y_regress**2)
            
            mdl_wls=sm.WLS(y_regress,X_ret,weights=weights).fit()
            selected_wls=[col for col in mdl_wls.model.exog_names if mdl_wls.pvalues[col]<=.1]
            
            
            sel_assets=[asset for asset in mini_tbl['ric']]
            
            reduced_top=tbl_ek_last[sel_assets]
            ret_ser_yr=np.mean((reduced_top/reduced_top.shift(1)-1).iloc[1:],axis=1)
            port_ser=pd.concat((port_ser,ret_ser_yr),axis=0)
            
            reduced_knockoff=tbl_ek_last[selected_knockoff]
            ret_ser_yr_knockoff=np.mean((reduced_knockoff/reduced_knockoff.shift(1)-1).iloc[1:],axis=1)
            knockoff_ser=pd.concat((knockoff_ser,ret_ser_yr_knockoff),axis=0)
            knock_mini=pd.DataFrame()
            for asset in selected_knockoff:
                knock_mini=knock_mini.append(mini_tbl[mini_tbl['ric']==asset])
            
            knock_mini=knock_mini.reset_index(drop=True)
            
            reduced_wls=tbl_ek_last[selected_wls]
            ret_ser_yr_wls=np.mean((reduced_wls/reduced_wls.shift(1)-1).iloc[1:],axis=1)
            wls_ser=pd.concat((wls_ser,ret_ser_yr_wls),axis=0)
            wls_mini=pd.DataFrame()
            for asset in selected_wls:
                wls_mini=wls_mini.append(mini_tbl[mini_tbl['ric']==asset])
            
            wls_mini=wls_mini.reset_index(drop=True)
            
            benchmark_oos=benchmark_df[np.logical_and(benchmark_df.index>=datetime(yr-1,12,25),
                                                      benchmark_df.index<=datetime(yr+1,1,1))]
            # if any([bench_idx.lower()=='market','sp' in bench_idx.lower(),'s&p' in bench_idx.lower()]):
                
            #     index_level=[float(100)]
            #     __=[index_level.append(index_level[-1]*(1+chng)) for chng in benchmark_oos.iloc[1:]]
                
            #     benchmark_oos=pd.DataFrame(data=benchmark_oos)
            #     benchmark_oos['level']=index_level
            # else:
            #     benchmark_oos=pd.DataFrame(data=benchmark_oos)
            #     benchmark_oos.columns=['level']
            
            benchmark_last_price=benchmark_oos.iloc[0,-1]
            bench_oos_last_price=benchmark_oos.iloc[-1,-1]
            
            
            
            ret_port=np.nanmean(mini_tbl['last price OOS']/mini_tbl['last price']-1)
            port_ret.append(ret_port)
            
            knockoff_ret_port=np.nanmean(knock_mini['last price OOS']/knock_mini['last price']-1)
            knockoff_ret.append(knockoff_ret_port)
            count_knockoff.append(len(selected_knockoff))
            
            wls_ret_port=np.nanmean(wls_mini['last price OOS']/wls_mini['last price']-1)
            wls_ret.append(wls_ret_port)
            count_wls.append(len(selected_wls))
            
            
            bench_ret.append(bench_oos_last_price/benchmark_last_price-1)
            t01=datetime.now()
            d0t=t01-t00
            if verbose:
                print('analysis for year '+str(yr)+' completed after '+str(d0t.total_seconds())+' seconds')
            
           
        res_tbl=pd.DataFrame(data=(study_range,port_ret,wls_ret,count_wls,
                                   knockoff_ret,count_knockoff,
                                   bench_ret,count_considered)).transpose()
        res_tbl.columns=['year',approach,'WLS','WLS knockoff',
                         'knockoff','count knockoff',
                         bench_idx,'considered count']
        db_ff[(approach+' ret')]=[port_ser[0].iloc[idx]-db_ff['rf'].iloc[idx] for idx in range(0,port_ser.shape[0])]

        db_ff['knockoff ret']=[knockoff_ser[0].iloc[idx]-db_ff['rf'].iloc[idx] for idx in range(0,knockoff_ser.shape[0])]
        
        db_ff['wls ret']=[wls_ser[0].iloc[idx]-db_ff['rf'].iloc[idx] for idx in range(0,knockoff_ser.shape[0])]
        
        mdl_ols=sm.OLS(db_ff[(approach+' ret')],sm.add_constant(db_ff.iloc[:,1:5]),missing='drop').fit()
        if verbose:
            print('\n summary for '+approach+' ...')
            print(mdl_ols.summary())
            
        mdl_ols_wls=sm.OLS(db_ff['wls ret'],sm.add_constant(db_ff.iloc[:,1:5]),missing='drop').fit()
        if verbose:
            print('\n summary for WLS ...')
            print(mdl_ols_wls.summary())

        mdl_ols_knockoff=sm.OLS(db_ff['knockoff ret'],sm.add_constant(db_ff.iloc[:,1:5]),missing='drop').fit()
        if verbose:
            print('\n summary for knockoff ...')
            print(mdl_ols_knockoff.summary())
        
        if approach!='cap':
            fl_name_tex=approach+'_top'+str(count_top)+'_'+str(study_range[0])+'_'+\
                           str(study_range[-1])+'_min-'+str(min_cap)+\
                           '_'+my_freq+'_'+bench_idx+'.tex'
        else:
            fl_name_tex=approach+'_top'+str(count_top)+'_'+str(study_range[0])+'_'+\
                           str(study_range[-1])+\
                           '_'+my_freq+'_'+bench_idx+'.tex'
         
        if verbose:
            print(res_tbl.to_string())
        if approach!='cap':
            res_tbl.to_csv(approach+'_top'+
                           str(count_top)+'_'+str(study_range[0])+'_'+
                           str(study_range[-1])+'_min-'+str(min_cap)+
                           '_'+my_freq+'_'+bench_idx+'.csv',index=False)
        else:
            res_tbl.to_csv(approach+'_top'+
                           str(count_top)+'_'+str(study_range[0])+'_'+
                           str(study_range[-1])+'_'+my_freq+'_'+bench_idx+'.csv',index=False)

        with open(fl_name_tex,'w') as f:
            f.write('\\newpage \n\\textbf{EW '+approach.capitalize()+' top '+str(count_top)+'} \n\n')
            f.write(mdl_ols.summary().as_latex())
            f.write('\n\\newpage \n\\textbf{EW WLS selected} \n\n')
            f.write(mdl_ols_wls.summary().as_latex())
            f.write('\n\\newpage \n\\textbf{EW Knockoff selected} \n\n')
            f.write(mdl_ols_knockoff.summary().as_latex())
            
            f.close()    
        value_bench=[100]
        __=[value_bench.append(value_bench[-1]*(1+chng_bench)) for chng_bench in bench_ret]

        approach_val=[100]
        __=[approach_val.append(approach_val[-1]*(1+chng_approach)) for chng_approach in port_ret]

        knockoff_val=[100]
        __=[knockoff_val.append(knockoff_val[-1]*(1+chng_knockoff)) for chng_knockoff in knockoff_ret]
        
        wls_val=[100]
        __=[wls_val.append(wls_val[-1]*(1+chng_wls)) for chng_wls in wls_ret]


        year_ser=pd.period_range(start=study_range[0]-1,end=study_range[-1],freq='A').end_time
        if approach!='cap':
            fl_name_fig=approach+'_top'+str(count_top)+'_'+str(study_range[0])+'_'+\
                           str(study_range[-1])+'_min-'+str(min_cap)+\
                           '_'+my_freq+'_'+bench_idx+'.png'
        else:
            fl_name_fig=approach+'_top'+str(count_top)+'_'+str(study_range[0])+'_'+\
                           str(study_range[-1])+\
                           '_'+my_freq+'_'+bench_idx+'.png'
        if visualise:
            import matplotlib.pyplot as plt
            fig,ax=plt.subplots()
            ax.set_xmargin(0)
            ax.plot(year_ser,value_bench,'s-k',label=bench_idx)
            ax.plot(year_ser,approach_val,'s:r',label=('EW '+approach))
            ax.plot(year_ser,knockoff_val,'s--b',label='EW knockoff')
            ax.plot(year_ser,wls_val,'s--g',label='EW wls')
            if any([np.max(approach_val)>1000,np.max(knockoff_val)>1000,np.max(wls_val)>1000]):
                ax.set_yscale('log')
            ax.set_ylabel('portfolio $ value')
            if approach=='cap':
                ax.set_title('top count = '+str(count_top))
            else:
                ax.set_title('top count = '+str(count_top)+', min cap = '+str(min_cap)+'M')
            ax.legend()
            plt.savefig(fl_name_fig,dpi=300)
            plt.show(block=False)




# cusip9_list=mini_tbl['cusip'].tolist()

# cusip8_list=[cusip_matcher(cusip9,matched_cusip) for cusip9 in cusip9_list]
# # iterr=0
# # for idx in range(0,mini_tbl.shape[0]):
# #     cusip=mini_tbl['cusip'].iloc[idx]
# #     iterr+=1
# #     try:
# #         matched_cusip8=matched_cusip[matched_cusip['cusip9']==cusip]['cusip8'].iloc[0]
# #     except:
# #         matched_cusip8='null'
# #     if verbose:
# #         print('iteration: '+ str(iterr)+', cusip: '+cusip+', matched CUSIP8: '+matched_cusip8)
# #     cusip8_list.append(matched_cusip8)

# mini_tbl['cusip8']=cusip8_list

# mini_tbl=mini_tbl[mini_tbl['cusip8']!='null'].reset_index(drop=True)
# unique_cusip8=[((mini_tbl.iloc[:idx][mini_tbl['cusip8']==mini_tbl.iloc[idx]['cusip8']]).shape[0]==0) for idx in mini_tbl.index]
# mini_tbl=mini_tbl[unique_cusip8].reset_index(drop=True)

# sql_last_price=""" select msf.date, msf.cusip, msf.prc, msf.ret, 
# msf.shrout, msf.cfacpr, msf.cfacshr, msfhdr.hshrcd, msfhdr.htick
# from crsp_a_stock.msf join crsp_a_stock.msfhdr on msfhdr.hcusip=msf.cusip
# where date>'"""+str(yr-1)+"""-12-01' and 
# date<'"""+str(yr+1)+"""-01-01' and 
# hshrcd>=10 and hshrcd<=11 order by cusip,date"""

# tbl_crs=db.raw_sql(sql_last_price,date_cols='date')
# tbl_crs=tbl_crs.set_index('date')

# unique_cusip8=np.unique(tbl_crs['cusip']).tolist()

# last_price=np.zeros_like(mini_tbl['cusip'])
# last_shrout=np.zeros_like(mini_tbl['cusip'])
# last_price_oos=np.zeros_like(mini_tbl['cusip'])

# for s in range(0,mini_tbl.shape[0]):
#     cusip8=mini_tbl['cusip8'].iloc[s]
#     if cusip8 in unique_cusip8:
#         if all([tbl_crs[tbl_crs['cusip']==cusip8].index[0].date().year==yr-1,
#                tbl_crs[tbl_crs['cusip']==cusip8].index[0].date().month==12]):
#             last_price[s]=np.abs(tbl_crs[tbl_crs['cusip']==cusip8].iloc[0]['prc'])/tbl_crs[tbl_crs['cusip']==cusip8].iloc[0]['cfacpr']
#             last_shrout[s]=tbl_crs[tbl_crs['cusip']==cusip8].iloc[0]['shrout']*tbl_crs[tbl_crs['cusip']==cusip8].iloc[0]['cfacshr']/1e3
#             if pd.isna(last_price[s]):  
#                 last_price[s]=0
#             else:
#                 if pd.isna(tbl_crs[tbl_crs['cusip']==cusip8].iloc[-1]['prc']):
#                     last_price_oos[s]=tbl_crs[tbl_crs['cusip']==cusip8].iloc[-2][
#                         'prc']/tbl_crs[tbl_crs['cusip']==cusip8].iloc[-2]['cfacpr']
#                 else:
#                     last_price_oos[s]=np.abs(tbl_crs[tbl_crs['cusip']==cusip8].iloc[-1][
#                         'prc'])/tbl_crs[tbl_crs['cusip']==cusip8].iloc[-1]['cfacpr']