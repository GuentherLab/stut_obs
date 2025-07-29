function [T,X1,X2,x] = design_efficiency_glm(X,C,varargin)
% (copied from design_efficiency toolbox 2023/06)
% DESIGN_EFFICIENCY_GLM computes design efficiency of GLM single-
% contrast estimation for 1st-level BOLD timeseries analyses
% from sub-sample design matrix and contrast vector/matrix
%
% T = design_efficiency_glm(X,C,varargin)
% X : design matrix [Nt x Ne]
% C : contrast vector [1 x Ne]
% T : design efficiency (expected T-stat @ SNR=1)
%       note: unlike T-stats design efficiency is scale dependent;
%       SNR represents the ratio between contrast value effect-
%       size (C*B | B=X\Y) and standard deviation of residual GLM 
%       model error (e.g. SNR=1 represents a case where the contrast
%       effect-size is as large as the residual BOLD signal error
%       standard deviation)
%
% Additional parameters: design_efficiency_glm(X,C, param_name1, param_value1, param_name2, param_value2, ...)
%
%   hparam  : high-pass filter threshold in seconds (inf for no filter) (default 120)
%   nparam  : noise 1/(1+nparam*f) shape param (inf for white noise) (default 120)
%   convhrf : convolve design matrix with canonical HRF (default true)
%             note: results are inaccurate if dt value is large; if your study has large TR values use sub-sampling resolution to define the design matrix X
%   hrfp    : parameters of hemodynamic response function (default [6 16 1 1 6 0 32]; see spm_hrf)
%   dt      : sample time between sequential rows of X in seconds (default 0.1s)
%   scans   : index to scan number for each row of X [Nt x 1] (numbers ranging from 1 to Nscans; 0 for not scanned) ([] for one row per scan) (default [])
%
% e.g. 1
%   X = full(sparse(1:100,randi(3,1,100),1,100,3));
%   C = [1 -1 0];
%   T = design_efficiency_glm(X, C, 'dt', 0.1);
% 
% e.g. 2
%   T=zeros(1,1e5);
%   maxT=0;
%   for n=1:numel(T), 
%       x = full(sparse(1:100,randi(3,1,100),1,100,3));
%       T(n)=design_efficiency_glm(x, [-1 1 0;0 -1 1], 'dt', .600); 
%       if T(n)>maxT, 
%           maxT=T(n); subplot(121); hist(T(1:n),100); title('design efficiency');
%           X=x; subplot(122); imagesc(X); title(sprintf('design matrix @ efficiency=%.2f',maxT));
%           drawnow;
%       end
%   end

%

% alfnie@gmail.com 2021

persistent dt hrfp hrf acor
params=struct(...
        'dt',.1,...        
		'hparam',120,...        
		'nparam',120,...       
        'addconstant',false,...
        'addacqeffect',true,...
        'convhrf',true,...     
        'hrfp',[6 16 1 1 6 0 32],...
        'whiten',true,...     
        'scans',[]);
for n1=1:2:numel(varargin)-1, assert(isfield(params,lower(varargin{n1})),'unrecognized parameter %s',varargin{n1}); params=setfield(params,lower(varargin{n1}),varargin{n1+1}); end
if isempty(acor), h=spm_hrf(1); acor=convn(h,flipud(h)); acor=acor(numel(h):end); end
if isempty(params.scans), params.scans=1:size(X,1); end

% Convolves design matrix with high-pass filter & inverse noise
if params.addacqeffect
    X=[X params.scans>0];
    C=[C zeros(size(C,1),1)];
end
if params.convhrf
    assert(params.dt<=1, 'dt value too large for hrf convolution. Please resample the design matrix to higher resolution and decrease dt');
    if isempty(dt)||dt~=params.dt||isempty(hrfp)||~isequal(hrfp,params.hrfp), dt=params.dt; hrfp=params.hrfp; hrf=spm_hrf(dt,hrfp); end
    x=convn(X,hrf,'full');
    X=x(1:size(X,1),:);
end
if params.addconstant
    X=[X-repmat(mean(X,1),size(X,1),1) ones(size(X,1),1)];
    C=[C zeros(size(C,1),1)];
end
X1=X;
n=2*size(X,1);
f=[0:n/2,n/2-1:-1:1]'/params.dt/n;
hpfilt=(f>=1/params.hparam); 
if params.whiten, noiseinv=hpfilt./(1+1./max(eps,f*params.nparam));
else noiseinv=hpfilt;
end
Xf=fft([X;flipud(X)],n);
Xf=repmat(noiseinv,[1,size(Xf,2)]).*Xf; % whitens design with inverse noise
X=real(ifft(Xf,n));
X=X(1:n/2,:);
k=1/mean(1./noiseinv(noiseinv>0).^2); % 1/mse
X2=X;

% Resamples design matrix at acq times
i=params.scans(:);
nscans=max(i);
valid=i>0;
x=zeros(nscans,size(X,2));
for n=reshape(find(ismember(1:nscans,i)),1,[]), x(n,:)=mean(X(i==n,:),1); end

% Estimate temporal autocorrelation between acq samples
tscan=params.dt*arrayfun(@(n)mean(find(i==n)),1:nscans);
R=interp1((0:numel(acor)-1)',acor,min(numel(acor)-1, abs(repmat(tscan,nscans,1)-repmat(tscan',1,nscans))));
l=trace(R)^2/trace(R*R');
%disp([nscans l]);

% disregard non-estimable contrasts
if size(C,1)==1
    opp=eye(size(x,2));
    try
        sX=spm_sp('Set',x);
        if sX.rk>0, opp=sX.v(:,[1:sX.rk])*sX.v(:,[1:sX.rk])'; 
        else opp=zeros(size(x,2));
        end
    end
end

% Computes efficiency
% note: expected t-stats = SNR*T
iXX=pinv(x'*x);
T=zeros(1,size(C,3));
for n1=1:size(C,3),
    if size(C,1)~=1||all(all(abs(opp*C(:,:,n1)' - C(:,:,n1)') <= sX.tol))
        r=diag(C(:,:,n1)*iXX*C(:,:,n1)');
        T(n1)=mean(sqrt(max(0,k./r)*l/nscans));
        %disp(mat2str([k mean(r) l nscans]));
    end
end

% if params.dodisp
%     [nill,idx]=max(X,[],2);
%     idx(nill==0)=0;
%     idx(SCAN>0)=size(X,2)+1;
%     clf; image(dt*(0:numel(SCAN)-1),1,1+idx'); set(gca,'ydir','normal'); hold all; plot(dt*(0:numel(SCAN)-1),1+.5*X1(:,1:end-1),'-','linewidth',2); plot(dt*(0:numel(SCAN)-1),1+.5*X1(:,end),':','color',.75*[1 1 1],'linewidth',2); colormap(1-.25*gray); set(gca,'xlim',[0 60],'ylim',[.8 1.6],'ytick',[]); xlabel('time (s)'); legend('C1','C2','C3','C4','C5','scan');
%     c=get(gca,'colororder'); colormap([1 1 1;.5+.5*c(1:size(X,2),:);.9 .9 .9]);
% end

