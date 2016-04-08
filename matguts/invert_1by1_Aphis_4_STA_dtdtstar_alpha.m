function [ dtstar_pref,dT_pref,alpha_pref,alpha_misfits,dtstars,dTs ] ...
    = invert_1by1_Aphis_4_STA_dtdtstar_alpha( Amat,phimat,fmids,test_alphas,wtmat,amp2phiwt )
%[ dtstar_pref,dT_pref,alpha_pref,alpha_misfits,dtstars,dTs,A0s, E ] ...
%     = allin1invert_Aphis_4_STA_dtdtstar_alpha( Amat,phimat,freqs,test_alphas,wtmat,amp2phiwt )
%   Script to simultaneously invert pairwise frequency and phase spectra
%   for dtstar and dT at a whole array of stations, looping over a range of
%   alpha values, solving for the best-fitting alpha and the corresponding
%   dtstar and dT
% 
%  Amat and phimat are matrices each of size [handshake(Nstas) x Nfreq]
%  fmids is a vector of frequencies
%  test_alphas is the vector of alpha values (?0) to test
%  wtmat is a matrix of weights, the same size as Amat
% 
% if Q is frequency independent (alpha==0)
%     A = A0*exp(-pi*dtstar*f)
%     ln(A) = ln(A0) - pi*dtstar*f 
%     phi = (ln(f) - ln(fNq))*dtstar/pi + dT
% 
% elseif Q is frequency dependent (alpha~   =0)
%     A = A0*exp(-(pi/((2*pi)^alpha)) * f^(1-alpha) * dtstar)
%     ln(A) = ln(A0) - (pi/((2*pi)^alpha)) * f^(1-alpha) * dtstar
%     phi = 0.5*cot(alpha*pi/2)*f^alpha + dT


%% prelims
if nargin < 5 || isempty(wtmat)
    wtmat = ones(size(Amat));
end
if nargin < 6 || isempty(amp2phiwt)
    amp2phiwt = 1;
end

Npair = size(Amat,1);
Nstas = quadratic_solve(1,-1,-2*Npair);
Na = length(test_alphas);

%% results structures

dtstars = zeros(Nstas,Na);
dTs = zeros(Nstas,Na);

alpha_misfits = zeros(Na,1);

% loop on alphas
for ia = 1:length(test_alphas)
    alpha = test_alphas(ia);


    % loop over station pairs
    ui = zeros(2*Npair,1);
    uj = zeros(2*Npair,1);
    u  = zeros(2*Npair,1);
    count = 0;

    dtstar_pairwise = zeros(Npair,1);
    dT_pairwise = zeros(Npair,1);
    misfitnormed_pairwise = zeros(Npair,1);


    for is1 = 1:Nstas
    for is2 = is1+1:Nstas
        count = count+1; % count is the same as the handshake #
        % make elements of eventual G matrix
        ui(2*(count-1)+[1 2]) = count;
        uj(2*(count-1)+[1 2]) = [is1 is2];
        u (2*(count-1)+[1 2]) = [-1 1]; % delta is value of 2 - value of 1

        [ dtstar,dT,~,misfit,~ ] ...
            = invert_1pair_Aphi_4_dtdtstar(Amat(count,:),phimat(count,:),fmids, wtmat(count,:),amp2phiwt,alpha);

        dtstar_pairwise(count) = dtstar;
        dT_pairwise(count) = dT;
        misfitnormed_pairwise(count) = misfit./sum(wtmat(count,:)~=0); % weight  will be  1./misfit, normalised by number of datapoints
    end 
    end

    %% solve the least squares problem
    G = sparse(ui,uj,u,Npair,Nstas,2*Npair);

    W = 1./misfitnormed_pairwise; 

    % add constraint
    G(Npair+1,:) = 1;
    dtstar_pairwise(Npair+1,:)=0;
    dT_pairwise(Npair+1,:)=0;
    W = diag([W;1]);

    % kill bad pairs
    isbd = (1./misfitnormed_pairwise==0);
    G(isbd,:) = [];
    dtstar_pairwise(isbd) = [];
    dT_pairwise(isbd) = [];
    W(isbd,:) = []; W(:,isbd) = [];

    % results
    dtstars(:,ia) = (G'*W*G)\G'*W*dtstar_pairwise;
    dTs(:,ia) = (G'*W*G)\G'*W*dT_pairwise;
    
    E = [G*dtstars(:,ia) - dtstar_pairwise;
         G*dTs(:,ia)     - dT_pairwise];

    alpha_misfits(ia) = E'*diag([diag(W);diag(W)])*E;

    

end %loop on alphas

%% minimise misfit
alpha_pref = test_alphas(mindex(alpha_misfits));
dtstar_pref = dtstars(:,mindex(alpha_misfits));
dT_pref = dTs(:,mindex(alpha_misfits));

figure(77), clf;
plot(test_alphas,alpha_misfits,'-o')



end
