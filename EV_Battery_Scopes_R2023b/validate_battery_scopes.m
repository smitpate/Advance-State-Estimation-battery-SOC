function validate_battery_scopes(out)
if nargin==0, r=load('run_data.mat','out'); out=r.out; end
t=out.recorded.Time; d=squeeze(out.recorded.Data); if size(d,1)~=numel(t), d=d'; end
assert(size(d,2)==9 && numel(t)==1801,'Expected nine signals for 1801 samples');
assert(all(isfinite(d),'all'),'Nonfinite result');
z=d(:,1); I=d(:,5); V=d(:,6); traction=d(:,7); regen=d(:,8);
assert(max(abs(I-(traction-regen)))<1e-6,'Current-source orientation or Kirchhoff check failed');
assert(all(traction.*regen==0),'Commands overlap');
assert(max(I)>119 && min(I)<-59,'Discharge or regeneration missing');
assert(min(V)>262.5 && max(V)<420,'Battery voltage outside this test range');
assert(all(z>20 & z<95),'SOC test envelope exceeded');
q=114.2857142857;
zref=z(1)-100*[0;cumsum(I(1:end-1))]/(q*3600);
chargeError=max(abs(z-zref)); assert(chargeError<.05,'Built-in SOC disagrees with charge integration');
dz=diff(z); regenmask=I(1:end-1)<-1; discharge=I(1:end-1)>1;
assert(mean(dz(regenmask))>0 && mean(dz(discharge))<0,'Wrong SOC trend');
e=d(:,2:4)-z; Method=["Coulomb counting";"EKF";"EKF with sensor bias"];
RMSE_percentage_points=sqrt(mean(e.^2))'; MAE_percentage_points=mean(abs(e))';
metrics=table(Method,RMSE_percentage_points,MAE_percentage_points); disp(metrics);
assert(RMSE_percentage_points(2)<RMSE_percentage_points(1),'EKF did not improve SOC estimation');
writetable(metrics,'Estimator_results.csv');
signals=array2table([t d],'VariableNames',{'Time_s','True_SOC_percent','CC_percent','EKF_percent','Bias_EKF_percent','Battery_current_A','Battery_voltage_V','Discharge_source_A','Regen_source_A','Estimated_bias_A'});
writetable(signals,'Recorded_scope_signals.csv');
f=fopen('Verified_results.txt','w'); c=onCleanup(@() fclose(f));
fprintf(f,'MATLAB %s\nPASS: 1801 finite samples over 1800 s.\nPASS: total battery current = discharge source - regen source.\nPASS: nonoverlapping current-source commands.\nPASS: discharge lowers SOC and regeneration raises SOC.\nPASS: native Battery SOC matches charge integration within %.8g percentage points.\nSOC %.5f to %.5f percent; current %.3f to %.3f A; voltage %.3f to %.3f V.\nFinal estimated bias %.5f A; injected bias 1.2 A.\n',version,chargeError,z(1),z(end),min(I),max(I),min(V),max(V),d(end,9));
for k=1:3, fprintf(f,'%s: RMSE %.6f, MAE %.6f percentage points\n',Method(k),RMSE_percentage_points(k),MAE_percentage_points(k)); end
fprintf('PASS: real Battery, two current sources and Scope signals validated. Final SOC %.3f percent.\n',z(end));
end
