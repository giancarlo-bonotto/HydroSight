function [AMALGAMPar] = DetN(Iout,AMALGAMPar);
% Determines the new number of points to generate with individual algorithms

% Define minN
minN = 5;

% First determine the number of new points generated by the total set of algorithms
T = sum(Iout > 0);

% Then calculate the percentage of individual algorithms
for qq = 1:AMALGAMPar.q,
    % Calc percentage
    perc(1,qq) = sum(Iout == qq)/AMALGAMPar.m(qq);
    % Calculate new size M
    M(1,qq) = perc(1,qq);
end;

% Determine the sum of M
Mnew = sum(M);

% Now do check whether new points have been added to ParGen
if Mnew == 0,
    M = (AMALGAMPar.N/AMALGAMPar.q) * ones(1,AMALGAMPar.q);
else
    % Define scaling parameter
    Scaling = 1/Mnew;
    % Do scaling so adds up to 100 percent
    M = max(floor(Scaling * M * AMALGAMPar.N),minN);
    % Now check whether everything is fine
    Mnew = sum(M); Diff = (AMALGAMPar.N - Mnew);
    % Now adjust the one with the most points
    [i] = find(M==max(M)); M(i(1)) = M(i(1)) + Diff;
end;

% Update AMALGAMPar
AMALGAMPar.m = M;