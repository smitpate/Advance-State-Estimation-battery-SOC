function y=battery_observers(im,vm,p)
% p=[E0 K A B R Qinternal Qrated kc tau]. Current positive on discharge.
% Outputs: CC %, EKF %, augmented EKF %, estimated current offset A.
persistent cc x P xb Pb previousI
if isempty(cc)
 cc=.6; x=[.6;0]; P=diag([.15^2 25]);
 xb=[.6;0;0]; Pb=diag([.15^2 25 1]); previousI=im;
else
 a=exp(-1/p(9)); q=3600*p(7);
 cc=min(1,max(0,cc-previousI/q));
 F=[1 0;0 a]; G=[-1/q;1-a];
 x=F*x+G*previousI; P=F*P*F'+diag([1e-8 .1]);
 Fb=[1 0 1/q;0 a -(1-a);0 0 1];
 xb=Fb*xb+[G;0]*previousI; Pb=Fb*Pb*Fb'+diag([1e-8 .1 1e-5]);
end
x(1)=min(.99,max(.05,x(1))); xb(1)=min(.99,max(.05,xb(1)));
v=terminal(x(1),x(2),im,p); H=zeros(1,2);
H(1)=(terminal(x(1)+1e-5,x(2),im,p)-terminal(x(1)-1e-5,x(2),im,p))/2e-5;
H(2)=(terminal(x(1),x(2)+1e-3,im,p)-terminal(x(1),x(2)-1e-3,im,p))/2e-3;
R=.2^2; K=P*H'/(H*P*H'+R); x=x+K*(vm-v); J=eye(2)-K*H; P=J*P*J'+K*R*K';
vb=terminal(xb(1),xb(2),im-xb(3),p); Hb=zeros(1,3);
Hb(1)=(terminal(xb(1)+1e-5,xb(2),im-xb(3),p)-terminal(xb(1)-1e-5,xb(2),im-xb(3),p))/2e-5;
Hb(2)=(terminal(xb(1),xb(2)+1e-3,im-xb(3),p)-terminal(xb(1),xb(2)-1e-3,im-xb(3),p))/2e-3;
Hb(3)=p(5); Kb=Pb*Hb'/(Hb*Pb*Hb'+R); xb=xb+Kb*(vm-vb); Jb=eye(3)-Kb*Hb; Pb=Jb*Pb*Jb'+Kb*R*Kb';
x(1)=min(1,max(0,x(1))); xb(1)=min(1,max(0,xb(1))); xb(3)=min(5,max(-5,xb(3)));
previousI=im; y=[100*cc;100*x(1);100*xb(1);xb(3)];
end
function v=terminal(z,ifilt,i,p)
it=(1-z)*p(7); Q=p(6);
if ifilt>=0, den=Q-it; else, den=it+Q*p(8); end
v=p(1)-p(2)*Q/(Q-it)*it+p(3)*exp(-p(4)*it)-p(2)*Q/den*ifilt-p(5)*i;
end
