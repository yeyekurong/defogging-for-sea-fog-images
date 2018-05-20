
function [L1, L2] = sepglow5(I,lambda,lb,hb,L1_0)
% Layer Separation using Relative Smoothness (general)
% [L1 L2] = septRelSmo(I,lambda,lb,hb,I0)
% I: input
% lambda: smoothness regularization parameter on the smoother layer Layer 2 
% lb: lower bound of the Layer 1,need to be same dimention with input I 
% hb: upper bound of the Layer 1,need to be same dimention with input I
% I0: initialization of Layer 1, default as the input I
pad_size = 64;
I = padarray(I,[pad_size,pad_size],'replicate','both');
lb = padarray(lb,[pad_size,pad_size],'replicate','both');
hb = padarray(hb,[pad_size,pad_size],'replicate','both');

lambda2 = 0.01;   %%%%%%0.001 Ũ��Ҫ��һЩ, ����L2���ȴ�С��,Խ��L2���� L2������ղ���͸���ʸߣ���LR������ͼ��ȥ����������ǹ���ᵼ�±�Եartifacts
if ~exist('I0','var')
    L1_0 = I;
end
[N,M,D] = size(I);

% filters
f1 = [1, -1];
f2 = [1; -1];
f3 = [0, -1, 0; 
      -1, 4, -1;
      0, -1, 0];
f3 = [-1 -1 -1;
      -1 8 -1;
      -1 -1 -1];
f4 = [1 1 1;
      1 1 1;
      1 1 1];
f5 = fspecial('gaussian',10,3);
f4 = f4/sum(f4(:));
sizeI2D = [N,M];
otfFx = psf2otf(f1,sizeI2D);
otfFy = psf2otf(f2,sizeI2D);
otfL = psf2otf(f3,sizeI2D);
otfI = psf2otf(f5,sizeI2D);
% Weight = CalWeightFun(I);
% Weight = Weight.*Weight;
Weight = ones(sizeI2D);
Normin1 = repmat(abs(otfL),[1,1,D]).^2.*fft2(I).*repmat(Weight,[1,1,D]);
Denormin1 = abs(otfL).^2.*Weight;
Denormin2 = abs(otfFx).^2 + abs(otfFy ).^2;
intensity = lambda2*abs(otfI).^2;

if D>1
    Denormin1 = repmat(Denormin1,[1,1,D]);
    Denormin2 = repmat(Denormin2,[1,1,D]);
    intensity = repmat(intensity,[1,1,D]);
end

eps = 1e-16;
L1 = L1_0;

thr = 0.05;   %%%%%Ĭ��0.05
r = round(min(N,M)*0.035);  %%%%1080 40
r_eps = 10^-2;
for i = 1:4  %%%%%%%���������ļӴ�ᵼ��L1��Ƶ���ָ���һЩ 8

    beta = 2^(i-1)/thr;
    Denormin   = lambda*Denormin1 + beta*Denormin2;
    %% update g
    gFx = -imfilter(L1,f1,'circular');  %%�൱imfilter(L1,[-1,1],'circular'); 
    gFy = -imfilter(L1,f2,'circular');
    %gL = imfilter(L1,f3,'circular');
    %t = repmat(sum(abs(gFx),3)<1/beta,[1 1 D]);
    %gFx(t) = 0;
    %t = repmat(sum(abs(gFy),3)<1/beta,[1 1 D]);
    %gFy(t) = 0;  %%%%%�Ѿ���ͬ��ҹ��ȥ���ˣ�ҹ��ȥ��֤L1�ݶȲ���С��ĳ��ֵ�������ݶ�����L1���ʸߣ�С�ݶ�����L2���ʸߡ�
    %%%%%%%���ǵķ�����ʹ��1������Լ��L1��
    gFx = max(abs(gFx) - 1/ beta, 0) .* sign(gFx); 
    gFy = max(abs(gFy) - 1/ beta, 0) .* sign(gFy); 
    
    %% compute L1
    Normin2 = [gFx(:,end,:) - gFx(:, 1,:), -diff(gFx,1,2)];   %%%�������Ҫ����Ҫ��λ�����ʱҪ��imfilter ��full���������ӣ�ȡǰn��m��
    Normin2 = Normin2 + [gFy(end,:,:) - gFy(1, :,:); -diff(gFy,1,1)];
%     Normin2 = [ -diff(gFx,1,2),gFx(:,end,:) - gFx(:, 1,:)];   %%%�൱imfilter(gFx,[1,-1],'circular');
%     Normin2 = Normin2 + [ -diff(gFy,1,1);gFy(end,:,:) - gFy(1, :,:)];
%     Normin2 = imfilter(gFx,[1,-1],'circular');;
%     Normin2 = Normin2 + imfilter(gFy,[1;-1],'circular');

    FL1 = (lambda*Normin1 + beta*fft2(Normin2))./(Denormin+eps+intensity);
    L1 = real(ifft2(FL1));

%     %% normalize L1
%     for c = 1:D%%%%%%%������Ե���Ϊ����ķ���
%         L1t = L1(:,:,c);
%         channel = I(:,:,c);
%         for k = 1:500
%         dt = (sum(L1t(L1t<lb(:,:,c)) )+ sum(L1t(L1t>hb(:,:,c)))-sum(channel(L1t>hb(:,:,c))))*2/numel(L1t);  %%%%%-sum  ��Ϊ�˷�ֹ�����𵴲�����
%         L1t = L1t-dt;
%         if abs(dt)<0.0001%%%1/numel(L1t)%%%%0.001 %%%%%%����ط������Ż��ӿ��ٶ�
%             break; 
%         end
%         end
%         L1(:,:,c) = L1t;
%     end
    %% normalize L1
    for c = 1:D%%%%%%%������Ե���Ϊ����ķ���
        L1t = L1(:,:,c);
        channel = I(:,:,c);
        options = ['Algorithm','guasi-newton']; %%guasi-newton,,,trust-region
        [t] = fminunc(@fun1,1,options,L1t,channel);
        L1(:,:,c) = L1t+t;
    end
    t = L1<lb;
    L1(t) = lb(t);
    t = L1>hb;
    L1(t) = hb(t);
    
    %% L2
%     L2 = I - L1;
%     L2_coarse = min(L2,[],3);
%     L2_g = guidedfilter_color(L1, L2_coarse, r, r_eps);
%     L2 = repmat(L2_g,[1,1,D]);
%     L1 = I - L2;
    L2 = I - L1;
%     imwrite(L2,'G.png');
    %L2 = repmat(min(L2,[],3),[1,1,D]);
    
%     L2_p = L2(pad_size+1:N-pad_size,pad_size+1:M-pad_size,:);
%     imwrite(L2_p,['L2_',num2str(i),'.jpg']);
%     L1 = I - L2;
%     n1 = abs(imfilter(L2,f3,'same'));
%     n2 = abs(imfilter(L1,f1,'same')) + abs(imfilter(L1,f2,'same'));
%     n3 = imfilter(L1,f5,'same');
%     %res(i) = lambda*power(norm(n1(:),2),2) + norm(n2(:),1) + lambda2*norm(n3(:),1);
%     res(i) = power(norm(n1(:),2),2) + norm(n2(:),1) + norm(n3(:),1);

end
L1 = L1(pad_size+1:N-pad_size,pad_size+1:M-pad_size,:);
L2 = L2(pad_size+1:N-pad_size,pad_size+1:M-pad_size,:);
I = I(pad_size+1:N-pad_size,pad_size+1:M-pad_size,:);

%%%%%���˲��������������ԵЧ�������Ȼ�������������Ҳ�������Ȧ������Ч��һ��ȴ���������ȦЧӦ
L2_coarse = min(L2,[],3);
% L2_g2 = fastguidedfilter(max(L1,[],3), L2_coarse, 10, 10^-4,4);
L2_g2 = wlsFilter(L2_coarse,0.5, 1.5, min(L1,[],3));          %%%%%%%%%%%%�Ա�Ե�������Ϻã�Ĭ��Ϊ1��1.2����ԭԭ����0.5��1.5����ƽ��,������Ե��������L2Ӧ����ƽ���ģ�����ȡ1.5 �� 1.2
% L2_g2 = L2_coarse;
% L2_g2 = qxfilter(L2_coarse,0.01,0.05);

L2 = repmat(L2_g2,[1,1,D]);
L1 = I - L2;




% gF = imfilter(L2,f3,'circular');
% gF = gF.^2*lambda;
% gFr = gF(:,:,1);
% gFx2 = -imfilter(L1,f1,'circular');  %%�൱imfilter(L1,[-1,1],'circular'); 
% gFy2 = -imfilter(L1,f2,'circular');
% gF2 = beta*(gFx2 + gFy2 - gFx - gFy).^2;
% %     gF2 = min(gFxxx.^2*10000,1);
% gF2r = gF2(:,:,1);
% por = gF2r./(gFr+eps);


%%
function WFun = CalWeightFun(HazeImg)
% parameters setting
L = rgb2gray(HazeImg);
sigma = 0.5; 

% calculating the weighting function
% weighting function
% method = 'circular';
% d_r = imfilter(HazeImg(:, :, 1), D, method);
WFun = 1./(L+eps);
% WFun = exp(-(L) / sigma / 2);
