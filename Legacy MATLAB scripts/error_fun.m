function err_val=error_fun(varargin)
    w=varargin{1};
    x=varargin{2};
    y=varargin{3};
    
    cov_=cov(x);
    var_p=w*cov_*w';
    
    try 
        model_type=varargin{4};
    catch
        model_type=[];
    end
    if isempty(model_type)
        model_type='rmse';
    end
    switch model_type
        case 'rmse'
            err_val=(mean((x*w'-y).^2,'omitnan'))^.5;
        case 'mae'
            err_val=mean(abs(x*w'-y),'omitnan');
        case 'ret'
            err_val=-mean(x*w','omitnan');
        case 'sharpe'
            err_val=-(mean(x*w','omitnan')/(var_p^.5));
        case 'var'
            err_val=(var_p)^.5;
    end

end