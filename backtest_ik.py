#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Sun Sep 11 13:00:10 2022

@author: arman
"""
from datetime import datetime
from invest_knockoff import invest_knockoff as ik

base_fun=ik(study_range=range(2001,2022),verbose=True)
my_freq_sel='weekly'
approach_set=['value', 'growth']
count_top_set=[100]
min_cap_set=[500]
bench='Market'
for count_top in count_top_set:
    # t00=datetime.now()
    # __=base_fun.backtest(approach='cap',
    #                      count_top=count_top,
    #                      my_freq=my_freq_sel,bench_idx=bench)
    # t01=datetime.now()
    # print('case large cap completed after '+str((t01-t00).total_seconds()))
    for min_cap in min_cap_set:
        for approach in approach_set:
            t00=datetime.now()
            __=base_fun.backtest(min_cap=min_cap,
                                 count_top=count_top,
                                 approach=approach,
                                 bench_idx=bench,
                                 my_freq=my_freq_sel)
            t01=datetime.now()
            print('case '+approach+', min cap = '+str(min_cap)+
                  'M completed after '+str((t01-t00).total_seconds()))

    
