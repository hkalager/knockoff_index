addpath(genpath(pwd));

try
    [S]=knockoffs.filter(rand(500,5), rand(500,1),.1,{'fixed'} );
catch
    warning(' CVX package not found; installing the package ... no admin access required!');
    cvx_setup;
    
end