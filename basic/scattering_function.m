a = 0:1:360;
b = a/180*pi;
h = polar([0 2*pi], [0 10]);% �뾶��Χ0 ��1
hold on;
q = 0.2;
p = (1-q^2)./((1-2*q*cos(b)+q^2)).^1.5;
polar(b,p);


% a = 0:1:360;
% t = a/180*pi;
% h = polar([0 2*pi], [0 1]);% �뾶��Χ0 ��1
% hold on;
% polar(t,sin(2*t).*cos(2*t),'--r');