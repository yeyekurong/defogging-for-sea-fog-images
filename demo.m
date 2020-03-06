
clear all;
%close all;
addpath('basic');
img = 'D:\Git\defogging-for-sea-fog-images\sea-fog-dataset\275.jpg';
I = im2double(imread(img));
[H, W, D] = size(I);
figure,imshow(I);
% 
%%%%%%%%%%the illumination decomposition
% I: input
% lambda: corresponds to the alpha in Eq. (7) of the paper, control the sharpness of fog layer.
% lambda2: corresponds to the beta in Eq. (7) of the paper, control the illumination of G.
% lb: lower bound of the Layer 1,need to be same dimention with input I 
% I0: initialization of Layer 1, default as the input I
% fast: whether use the fast impletment, 1:fast 2:normal
%%%%%%%%%%the third parameter 
[alpha,beta, pro] = parameter_sel(I);
[LB, LR] = layer_decom(I, alpha, beta, zeros(H,W,D)+0.01, I, 2);  
%%%%%%%%%%the fog layer defogging  process. We utilized the improved Berman's algorithm in the process.  
gamma = 1.5;
[out_Im, trans_refined,ind] = non_local_dehazing_new(uint8((LB)*255),LR, gamma, pro);
out_Im = im2double(out_Im);
% figure,imshow(trans_refined);
% figure,imshow(out_Im);

%%%%%%%%%luminance conpensate process
% out_Im: input
% LR: the glow-shaped illumination layer.
% I: the original fog image.
% ga: the index in Eq.(17), which control the gamma transformation
[LR2,out_Im2] = luminance_com(out_Im,LR,I,1.6);
out_Im3 = out_Im2  + LR2;    
figure,imshow(out_Im3);

