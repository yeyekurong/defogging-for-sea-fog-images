function [LR3,out_q] = relectance_coff_o(out_Im,LR,I,alpha)
[H, W, D] = size(I);
eps = 10^-4;
% out_q = qxfilter(out_Im*255,0.01)/255;       %%%%%%%%��ȥ�룬���ղ�����ȥ���ںϵ�һ��������������Ϊ��������һ��ģ�͹��̵Ľ��ʡ�Ĭ��0.01
out_q = out_Im;
L1_max = (max(out_Im,[],3));
L1_min = (min(out_Im,[],3));
L1_max_g = fastguidedfilter(max(I,[],3), L1_max, uint16(H*0.04), eps,4);  %%%%%%%�˲������ڴ�С���� Ĭ��0.04
pp = minmaxfilt(double(L1_max),round(H*0.02),'max','same');
localmax = fastguidedfilter(max(I,[],3), pp, uint16(H*0.1), eps,4);%
ratio1=L1_max_g./(localmax+~localmax);    
% figure,imshow(ratio1);
lam = adjust(LR(:,:,1));  
% c = power(1./exp(max(lam - 0.5, 0)),alpha);%%%%%%%%%����������ѡ������������������ɫ���⣬ ��������������ɫ��ǳ����������ɫ�Ƚ���
c = (1-power(lam,alpha)).*(1-ratio1);
%%%%�����ǰ�ƽ�⣬һ��ʼ���а�ƽ�⣬��������ڽ��а�ƽ�⡣
R = (out_q(:,:,1))./L1_max_g;
G = (out_q(:,:,2))./L1_max_g;
B = (out_q(:,:,3))./L1_max_g;
R(R>1) = 1;
R(R<0) = 0;
G(G>1) = 1;
G(G<0) = 0;
B(B>1) = 1;
B(B<0) = 0;
R = R.^c;
G = G.^c;
B = B.^c;
ratio1_r = ratio1.*R;
ratio1_g = ratio1.*G;
ratio1_b = ratio1.*B;
LR2(:,:,1) = LR(:,:,1).*(ratio1_r);
LR2(:,:,2) = LR(:,:,2).*(ratio1_g);
LR2(:,:,3) = LR(:,:,3).*(ratio1_b);
% out_q(:,:,1) = max(out_q,[],3).*R;
% out_q(:,:,2) = max(out_q,[],3).*G;
% out_q(:,:,3) = max(out_q,[],3).*B;
LR2(LR2>1) = 1;
LR2(LR2<0) = 0;
LR3 = double(LR2.^(1/1.5));%%%%%%%%%����
figure,imshow(LR3);
end