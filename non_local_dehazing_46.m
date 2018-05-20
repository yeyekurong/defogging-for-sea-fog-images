function [img_dehazed, transmission, ind_dis] = non_local_dehazing(img_hazy,gamma,LR)

%   Input arguments:
%   ----------------
%	img_hazy     - A hazy image in the range [0,255], type: uint8
%	air_light    - As estimated by prior methods, normalized to the range [0,1]
%	gamma        - Radiometric correction. If empty, 1 is assumed
%
%   Output arguments:
%   ----------------
%   img_dehazed  - The restored radiance of the scene (uint8)
%   transmission - Transmission map of the scene, in the range [0,1]

%% The details of the algorithm are described in our paper: 
% Non-Local Image Dehazing. Berman, D. and Treibitz, T. and Avidan S., CVPR2016,
% which can be found at:
% www.eng.tau.ac.il/~berman/NonLocalDehazing/NonLocalDehazing_CVPR2016.pdf


%% Validate input
wls = 1;
show = 0;
[h,w,n_colors] = size(img_hazy);
if (n_colors ~= 3) % input verification
    error(['Non-Local Dehazing reuires an RGB image, while input ',...
        'has only ',num2str(n_colors),' dimensions']);
end
gamma = 1.3;
if ~exist('gamma','var') || isempty(gamma), gamma = 1.3; end

img_hazy = im2double(img_hazy);
img_hazy_corrected = img_hazy.^gamma; % radiometric correction

windowSize=round(min(h,w)*0.02);
Imax = min(img_hazy_corrected,[],3);
% Imax = (img_hazy_corrected(:,:,1) + img_hazy_corrected(:,:,2) + img_hazy_corrected(:,:,3))/3;
pp = minmaxfilt(double(Imax),windowSize,'min','same');
[count,scale]=imhist(pp);
sumpoint=0;
i=256;
while (sumpoint<h*w*0.0001)
    sumpoint=sumpoint+count(i);
    i=i-1;
end
temp=im2bw(Imax,double(i-1)/255);%��ͼ���ֵ������iΪ��
% temp = ones(h,w);
AR=double(temp).*double(img_hazy_corrected(:,:,1));
AG=double(temp).*double(img_hazy_corrected(:,:,2));
AB=double(temp).*double(img_hazy_corrected(:,:,3));%�ҵ�������ȵķֲ�ͼ�����ָ�����µ�ȫ����Ϊ0��������ȡ������ȡ�
% A1=double(max(max(AR)));  %Rͨ�����ص����ֵ
% A2=double(max(max(AG)));  %Gͨ�����ص����ֵ
% A3=double(max(max(AB)));  %Bͨ�����ص����ֵ  �����ⲻҪ���õĹ�С���������Ľ�����ɢ��͸����ͼҲ���ֺܶ�artifact
A1=double(summ(max(AR)));  %Rͨ�����ص����ֵ
A2=double(summ(max(AG)));  %Gͨ�����ص����ֵ
A3=double(summ(max(AB)));  %Bͨ�����ص����ֵ  �����ⲻҪ���õĹ�С���������Ľ�����ɢ��͸����ͼҲ���ֺܶ�artifact
% A_max = max(max(A1,A2),A3);
% air_light(:,:,1) = A_max;
% air_light(:,:,2) = A_max;
% air_light(:,:,3) = A_max;
air_light(:,:,1) = A1;
air_light(:,:,2) = A2;
air_light(:,:,3) = A3;
%% Find Haze-lines
% Translate the coordinate system to be air_light-centric (Eq. (3))
dist_from_airlight = double(zeros(h,w,n_colors));
for color_idx=1:n_colors
    dist_from_airlight(:,:,color_idx) = abs(img_hazy_corrected(:,:,color_idx) - air_light(:,:,color_idx));
end

% Calculate radius (Eq. (5))
radius = sqrt( dist_from_airlight(:,:,1).^2 + dist_from_airlight(:,:,2).^2 +dist_from_airlight(:,:,3).^2 );

% Cluster the pixels to haze-lines
% Use a KD-tree impementation for fast clustering according to their angles
dist_unit_radius = reshape(dist_from_airlight,[h*w,n_colors]);
dist_norm = sqrt(sum(dist_unit_radius.^2,2));
dist_unit_radius = bsxfun(@rdivide, dist_unit_radius, dist_norm);
n_points = 1000;
load pointdat2;
mdl = KDTreeSearcher(points2);       %%%%%%%%����knnsearch�еĲ��ԣ�������Դ�Ƕ�һ�����ͽ��������ʷ֣��õ��������Ͼ��ȷֲ��ĵ�������ݡ�
ind = knnsearch(mdl, dist_unit_radius);   %%%%%%%������㷨
ind_dis = reshape(ind,h,w);
ind_h = ind_dis(1:round(h/2),:);
K = accumarray(ind_h(:),1,[n_points,1]);
[num,ind_ix] = max(K);
ind_h = ind_dis(round(h/2):end,:);
ind_less = ind(ind == ind_ix);
[idx,nu] = kmeans(radius(ind == ind_ix),2);
if(nu(1) < nu(2))
   ind_less(idx == 1) = 1000;
   ind_less(idx == 2) = 1; 
else
   ind_less(idx == 1) = 1;
   ind_less(idx == 2) = 1000; 
end
ind2 = ind;
ind2(ind == ind_ix) = ind_less;
ind_dis = im2double(ind_dis)/1000;
% Estimate radius as the maximal radius in each haze-line (Eq. (11))
K = accumarray(ind,radius(:),[n_points,1],@max);
radius_new = reshape( K(ind), h, w);

% Estimate transmission as radii ratio (Eq. (12))
transmission_estimation = radius./radius_new;

% Limit the transmission to the range [trans_min, 1] for numerical stability
trans_min = 0.1;
transmission_estimation = min(max(transmission_estimation, trans_min),1);
% imwrite(transmission_estimation,'E:\QXH\����ȥ���㷨����\ȥ���㷨����\ҹ��\Li_iccv15_nighttime_haze\����Ա�\2_transmission.tif');


%% Regularization

% Apply lower bound from the image (Eqs. (13-14))
trans_lower_bound = 1 - min(bsxfun(@rdivide,img_hazy_corrected,reshape(air_light,1,1,3)) ,[],3);
transmission_estimation = max(transmission_estimation, trans_lower_bound);
 
% Solve optimization problem (Eq. (15))
% find bin counts for reliability - small bins (#pixels<50) do not comply with 
% the model assumptions and should be disregarded
bin_count       = accumarray(ind,1,[n_points,1]);
bin_count_map   = reshape(bin_count(ind),h,w);   %ͼƬÿ�����ص��Ӧ�Ҷȵ���������
bin_eval_fun    = @(x) min(1, x/50);

% Calculate std - this is the data-term weight of Eq. (15)
lam = adjust(LR(:,:,1));  
K_std = accumarray(ind,radius(:),[n_points,1],@std);   %ÿ��line�ϵİ뾶�ı�׼��
radius_std = reshape( K_std(ind), h, w);              %ͼƬÿ�����ص��Ӧ�뾶�ı�׼��
%%%%
% c = power(exp(lam - 1),3);
% radius_std(ind2 == 1000) = radius_std(ind2 == 1000) .*c(ind2 == 1000);
tr = transmission_estimation(ind2==1000);
tr = power(transmission_estimation/mean(tr),gamma);
% tr2 = ones(h,w);
% tr2(ind2==1000) = tr;
%%%%
radius_eval_fun = @(r) min(1, 3*max(0.01, r-0.1));
radius_reliability = radius_eval_fun(radius_std./max(radius_std(:)));%ÿ������ͨ����Ӧ�İ뾶�ı�׼�����������Ŷ�
c2 = 1./(1+exp((lam-1).*tr));
% c2 = 1;
transmission_estimation = 1-c2+c2.*transmission_estimation;
data_term_weight   = bin_eval_fun(bin_count_map).*radius_reliability; %Ȩ��
lambda = 0.01;
transmission = wls_optimization(transmission_estimation, data_term_weight, img_hazy, lambda);


%% Dehazing
% (Eq. (16))
img_dehazed = zeros(h,w,n_colors);
leave_haze = 1.03; % leave a bit of haze for a natural look (set to 1 to reduce all haze)1.06
for color_idx = 1:3
    img_dehazed(:,:,color_idx) = ( img_hazy_corrected(:,:,color_idx) - ...
        (1-leave_haze.*transmission).*air_light(color_idx) )./ max(transmission,trans_min);
end
% figure,imshow(img_dehazed*3);

% Limit each pixel value to the range [0, 1] (avoid numerical problems)
img_dehazed(img_dehazed>1) = 1;
img_dehazed(img_dehazed<0) = 0;
img_dehazed = img_dehazed.^(1/gamma); % radiometric correction



% For display, we perform a global linear contrast stretch on the output, 
% clipping 0.5% of the pixel values both in the shadows and in the highlights 
% adj_percent = [0.005, 0.995];
% img_dehazed = adjust(img_dehazed,adj_percent);

% img_dehazed = im2uint8(img_dehazed);

end % function non_local_dehazing
function [u_max] = max_gau(a)
u_mean = mean(a(:));
u_std = std(a(:));
u_max = u_mean + 3*u_std;
% u_max = max(a(:));
end
function [b] = summ(a)
b = sum(sum(a))/numel(find(a~=0));
end
