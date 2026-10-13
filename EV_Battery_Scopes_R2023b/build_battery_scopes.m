function build_battery_scopes
assert(strcmp(version('-release'),'2023b'),'Use R2023b only.');
folder=fileparts(mfilename('fullpath')); cd(folder); addpath(folder);
m='EV_Battery_Discharge_Regen'; if bdIsLoaded(m), close_system(m,0); end
load_system('sps_lib'); load_system('simulink'); new_system(m);
set_param(m,'Solver','FixedStepDiscrete','FixedStep','.05','StopTime','1800','ReturnWorkspaceOutputs','on');
inventory={};
b('sps_lib/powergui','powergui',[30 30 130 75],'Solves the connected SPS electrical network. Discrete 50 ms is suitable for this battery current-profile test, not PWM switching.','SimulationMode','Discrete','SampleTime','.05');
b('sps_lib/Sources/Battery','Lithium ion EV battery',[160 240 255 355],'Actual SPS Battery block with internal charge state and nonlinear charge/discharge voltage. This single block represents an EV pack, not a single 350 V cell.','BatType','Lithium-Ion','NomV','350','NomQ','114.2857142857','SOC','80','Batt_Tr','30','ShowTempParam','off','ShowAgeParam','off','PresetModel','on','current','[60 120 180]');
ws=get_param([m '/Lithium ion EV battery'],'MaskWSVariables'); Batt=ws(strcmp({ws.Name},'Batt')).Value;
p=[Batt.E0 Batt.K Batt.A Batt.B Batt.R Batt.Q Batt.Q/Batt.lambda Batt.kc 10];
mw=get_param(m,'ModelWorkspace'); assignin(mw,'observer_parameters',p); save('battery_parameters.mat','Batt','p');
b('sps_lib/Sensors and Measurements/Current Measurement','Battery current sensor',[325 190 385 225],'Measures total battery current. Positive means discharge; negative means charging.');
b('sps_lib/Sensors and Measurements/Voltage Measurement','Battery voltage sensor',[440 290 485 335],'Connected across the battery terminals to measure pack voltage without drawing current.');
b('sps_lib/Sources/Controlled Current Source','Discharge current source',[630 280 680 365],'Physical current-source load: draws 120 A from HV+ to HV- while traction pulse is high.','Orientation','down','Initialize','on','Source_Type','DC','Amplitude','0','Measurements','None');
b('sps_lib/Sources/Controlled Current Source','Regenerative current source',[880 280 930 365],'Separate physical current source connected in the opposite direction: injects 60 A into the battery positive terminal during braking.','Orientation','up','Initialize','on','Source_Type','DC','Amplitude','0','Measurements','None');
b('sps_lib/Utilities/Ground','Battery negative reference',[270 400 300 430],'Defines the negative electrical reference node.');
b('simulink/Sources/Pulse Generator','Traction command 120 A',[590 80 710 120],'Traction is ON from 60 to 360 s in each 600 s cycle.','Amplitude','120','Period','600','PulseWidth','50','PhaseDelay','60');
b('simulink/Sources/Pulse Generator','Braking command 60 A',[850 80 970 120],'Regeneration is ON from 420 to 540 s in each 600 s cycle, separate from traction.','Amplitude','60','Period','600','PulseWidth','20','PhaseDelay','420');
wire('Lithium ion EV battery','LConn',1,'Battery current sensor','LConn',1);
wire('Battery current sensor','RConn',1,'Discharge current source','LConn',1);
wire('Battery current sensor','RConn',1,'Regenerative current source','RConn',1);
wire('Lithium ion EV battery','LConn',2,'Discharge current source','RConn',1);
wire('Lithium ion EV battery','LConn',2,'Regenerative current source','LConn',1);
wire('Lithium ion EV battery','LConn',2,'Battery negative reference','LConn',1);
wire('Lithium ion EV battery','LConn',1,'Battery voltage sensor','LConn',1);
wire('Lithium ion EV battery','LConn',2,'Battery voltage sensor','LConn',2);
sig('Traction command 120 A/1','Discharge current source/1','Traction demand A');
sig('Braking command 60 A/1','Regenerative current source/1','Regen demand A');
b('simulink/Signal Routing/Bus Selector','Battery SOC output',[80 480 85 535],'Selects built-in SOC (%) from the Battery measurement bus. It is comparison truth and is never an estimator input.','OutputSignals','SOC (%)');
sig('Lithium ion EV battery/1','Battery SOC output/1','Battery measurements');
tag('Battery current sensor/1','Ipack',[330 245 400 270]);
tag('Battery voltage sensor/1','Vpack',[485 370 555 395]);
tag('Battery SOC output/1','SOCtrue',[120 500 195 525]);
tag('Traction command 120 A/1','Idischarge',[595 150 690 175]);
tag('Braking command 60 A/1','Iregen',[850 150 940 175]);
% Readable lower area: measured signals -> online estimator -> scopes.
from('Ipack','Current input',[280 525 350 550]);
from('Vpack','Voltage input',[280 620 350 645]);
b('simulink/Discrete/Zero-Order Hold','Sample current',[375 515 445 550],'Samples measured current once per second for the observer.','SampleTime','1');
b('simulink/Discrete/Zero-Order Hold','Sample voltage',[375 610 445 645],'Samples terminal voltage at the same 1-second observer rate.','SampleTime','1');
b('simulink/Sources/Random Number','Current sensor error',[360 710 470 745],'Adds a known +1.2 A offset and 0.25 A standard deviation noise to test current-sensor error.','Mean','1.2','Variance','.25^2','Seed','23','SampleTime','1');
b('simulink/Sources/Random Number','Voltage sensor error',[520 710 625 745],'Adds 0.15 V standard deviation pack-voltage noise, with a repeatable independent seed.','Mean','0','Variance','.15^2','Seed','47','SampleTime','1');
b('simulink/Math Operations/Sum','Measured current',[490 520 520 550],'Combines true measured current with the current-sensor error.','Inputs','++');
b('simulink/Math Operations/Sum','Measured voltage',[590 610 620 640],'Combines true terminal voltage with voltage-sensor noise.','Inputs','++');
sig('Current input/1','Sample current/1'); sig('Voltage input/1','Sample voltage/1');
sig('Sample current/1','Measured current/1'); sig('Current sensor error/1','Measured current/2');
sig('Sample voltage/1','Measured voltage/1'); sig('Voltage sensor error/1','Measured voltage/2');
b('simulink/Sources/Constant','Battery observer parameters',[685 715 855 745],'Stores E0,K,A,B,R,Qinternal,Qrated,kc,tau extracted from this Battery mask. Contains no true SOC.','Value','observer_parameters');
b('simulink/User-Defined Functions/MATLAB Function','SOC estimation',[725 535 900 660],'Online CC, EKF and augmented EKF. States are SOC and filtered current; the augmented filter adds current bias. All priors start at 60 percent.');
rt=sfroot; ch=rt.find('-isa','Stateflow.EMChart','Path',[m '/SOC estimation']); ch.Script=fileread(fullfile(folder,'battery_observers.m'));
sig('Measured current/1','SOC estimation/1','Measured I A'); sig('Measured voltage/1','SOC estimation/2','Measured V V'); sig('Battery observer parameters/1','SOC estimation/3');
b('simulink/Signal Routing/Demux','Estimator outputs',[950 525 955 675],'Separates the four observer outputs: CC percent, EKF percent, bias-EKF percent, estimated bias A.','Outputs','4'); sig('SOC estimation/1','Estimator outputs/1');
tag('Estimator outputs/1','SOCcc',[985 535 1060 560]); tag('Estimator outputs/2','SOCekf',[985 575 1060 600]); tag('Estimator outputs/3','SOCaug',[985 615 1060 640]); tag('Estimator outputs/4','Ibias',[985 655 1060 680]);
% Scope panels and their short local wires are arranged along the right.
scope('Battery V I SOC',[1260 180 1330 245],3,[3 1],{'Voltage V','Battery current A','True SOC percent'},{[320 420],[-80 140],[35 85]},'Primary Scope: voltage, signed battery current and built-in SOC on separate axes.');
scopefrom('Vpack','Voltage to Scope',[1125 165 1195 190],'Battery V I SOC/1','Battery voltage V');
scopefrom('Ipack','Current to Scope',[1125 205 1195 230],'Battery V I SOC/2','Battery current A');
scopefrom('SOCtrue','SOC to Scope',[1125 245 1195 270],'Battery V I SOC/3','Battery SOC percent');
scope('SOC comparison',[1260 400 1330 465],4,[1 1],{'True SOC and estimates (%)'},{[30 85]},'Shows true SOC, Coulomb counting, EKF and bias-EKF together in percent.');
scopefrom('SOCtrue','Truth comparison',[1125 345 1195 370],'SOC comparison/1','True SOC');
scopefrom('SOCcc','CC comparison',[1125 385 1195 410],'SOC comparison/2','Coulomb counting');
scopefrom('SOCekf','EKF comparison',[1125 425 1195 450],'SOC comparison/3','EKF');
scopefrom('SOCaug','Augmented comparison',[1125 465 1195 490],'SOC comparison/4','Bias EKF');
scope('Discharge and regeneration',[1260 615 1330 680],3,[1 1],{'Source commands and net battery current (A)'},{[-80 140]},'Shows two nonnegative branch source commands and measured signed net battery current. Ideal-source branch currents equal their commands.');
scopefrom('Idischarge','Discharge to Scope',[1125 575 1195 600],'Discharge and regeneration/1','Discharge source A');
scopefrom('Iregen','Regen to Scope',[1125 625 1195 650],'Discharge and regeneration/2','Regen source A');
scopefrom('Ipack','Net current to Scope',[1125 675 1195 700],'Discharge and regeneration/3','Net battery current A');
scope('Sensor bias estimate',[1260 800 1330 850],1,[1 1],{'Estimated current-sensor bias (A)'},{[-2 5]},'Displays the augmented EKF current-offset estimate. The injected offset is 1.2 A.');
scopefrom('Ibias','Bias to Scope',[1125 805 1195 830],'Sensor bias estimate/1','Estimated bias A');
% One small logging subsystem keeps file-export wiring off the circuit.
b('simulink/Ports & Subsystems/Subsystem','Saved test data',[40 695 175 755],'Records the same Scope signals at 1 s for automated checks and the results table.');
Simulink.SubSystem.deleteContents([m '/Saved test data']);
tags={'SOCtrue','SOCcc','SOCekf','SOCaug','Ipack','Vpack','Idischarge','Iregen','Ibias'};
for k=1:9
 b('simulink/Signal Routing/From',['Saved test data/' tags{k}],[30 35*k 120 35*k+20],['Fetches ' tags{k} ' for repeatable validation only.'],'GotoTag',tags{k});
end
b('simulink/Signal Routing/Mux','Saved test data/Combine',[190 40 195 335],'Combines nine scalar channels in the documented order.','Inputs','9');
b('simulink/Sinks/To Workspace','Saved test data/Log',[260 165 370 205],'Saves all nine channels as a timeseries named recorded, at 1 s; Scopes remain the primary output.','VariableName','recorded','SaveFormat','Timeseries','SampleTime','1');
for k=1:9, add_line([m '/Saved test data'],[tags{k} '/1'],['Combine/' num2str(k)],'autorouting','on'); end
add_line([m '/Saved test data'],'Combine/1','Log/1');
a=Simulink.Annotation(m,'350 V / 114.3 Ah Li-ion pack | discharge 120 A | regenerative charging 60 A'); a.Position=[210 35];
set_param(m,'ZoomFactor','FitSystem'); save_system(m,fullfile(folder,[m '.slx']));
write_inventory; print(['-s' m],'-dpng','Circuit.png'); fprintf('Built actual Battery + two current sources in %s\n',version);
 function b(lib,n,pos,why,varargin)
  add_block(lib,[m '/' n],'Position',pos); if ~isempty(varargin), set_param([m '/' n],varargin{:}); end
  set_param([m '/' n],'Description',why); inventory(end+1,:)={n,lib,why,varargin};
 end
 function sig(src,dst,varargin)
  h=add_line(m,src,dst,'autorouting','on'); if ~isempty(varargin), set_param(h,'Name',varargin{1}); end
 end
 function wire(n1,p1,k1,n2,p2,k2)
  h1=get_param([m '/' n1],'PortHandles'); h2=get_param([m '/' n2],'PortHandles'); add_line(m,h1.(p1)(k1),h2.(p2)(k2),'autorouting','on');
 end
 function tag(src,t,pos)
  b('simulink/Signal Routing/Goto',['Send ' t],pos,['Routes ' t ' by name to Scopes/observer without long crossing wires.'],'GotoTag',t,'TagVisibility','global'); sig(src,['Send ' t '/1']);
 end
 function from(t,n,pos), b('simulink/Signal Routing/From',n,pos,['Receives signal ' t ' from its matching Goto.'],'GotoTag',t); end
 function scopefrom(t,n,pos,dst,label), from(t,n,pos); sig([n '/1'],dst,label); end
 function scope(n,pos,np,layout,titles,limits,why)
  b('simulink/Sinks/Scope',n,pos,why,'NumInputPorts',num2str(np)); c=get_param([m '/' n],'ScopeConfiguration');
  c.LayoutDimensions=layout; c.TimeSpan='1800'; c.TimeSpanOverrunAction='Scroll'; c.ShowLegend=true; c.ShowGrid=true;
  c.LimitDataPoints=false;
  for d=1:numel(titles), c.ActiveDisplay=d; c.Title=titles{d}; c.YLimits=limits{d}; c.ShowLegend=true; c.ShowGrid=true; end
 end
 function write_inventory
  fid=fopen('Every_block_and_parameter.md','w'); cleaner=onCleanup(@() fclose(fid));
  fprintf(fid,'# Every block and why it is used\n\nModel: `%s`, built using MATLAB R2023b.\n\nSolver: FixedStepDiscrete; step 0.05 s; duration 1800 s. Observer and saved-data sample period: 1 s.\n\n',m);
  fprintf(fid,'The real Battery block represents a complete 350 V / 114.3 Ah EV pack. It is not a single physical cell. Its built-in SOC measurement is comparison truth only. Discharge-source current flows HV+ to HV-; the regeneration source is wired oppositely.\n\n');
  allparams=struct;
  for j=1:size(inventory,1)
   n=inventory{j,1}; block=[m '/' n]; fprintf(fid,'## %d. %s\n\n**Library:** `%s`\n\n%s\n\n',j,n,inventory{j,2},inventory{j,3});
   pars=inventory{j,4}; if isempty(pars), fprintf(fid,'No custom numerical setting; library defaults and inherited signal rate are used.\n\n'); else
    fprintf(fid,'| Parameter | Setting |\n|---|---|\n'); for v=1:2:numel(pars), fprintf(fid,'| `%s` | `%s` |\n',pars{v},pars{v+1}); end; fprintf(fid,'\n');
   end
   dp=get_param(block,'DialogParameters'); item=struct('Path',block,'Library',inventory{j,2},'Why',inventory{j,3},'DialogParameters',struct);
   if isstruct(dp), for f=fieldnames(dp)', try, item.DialogParameters.(f{1})=get_param(block,f{1}); catch, end; end; end
   allparams.(sprintf('Block_%02d',j))=item;
  end
  fprintf(fid,'## Battery auto-derived discharge parameters\n\nThese are the generic SPS nominal-parameter preset values, not manufacturer test data. Temperature and aging options are disabled; their inactive default fields do not affect this run.\n\n');
  bp={'NomV','NomQ','SOC','Batt_Tr','MaxQ','MinV','FullV','Dis_rate','R','Normal_OP','expZone'};
  for j=1:numel(bp), fprintf(fid,'- `%s = %s`\n',bp{j},get_param([m '/Lithium ion EV battery'],bp{j})); end
  fprintf(fid,'\n## Scope settings\n\nAll Scopes: 0 to 1800 s, grid and legend enabled, complete run retained (point limit disabled). Battery Scope: 3 rows, V [320,420], A [-80,140], SOC [35,85]. SOC comparison: one axis, [30,85] percent. Branch currents: one axis, [-80,140] A. Bias Scope: [-2,5] A.\n\n## Observer settings\n\n`battery_observers.m` is embedded in the MATLAB Function block. Both EKFs use the native Battery nonlinear voltage model, including separate charging/discharging polarization expressions. The CC and both EKF prior SOC values are 0.60; initial filtered current is 0 A and initial bias is 0 A.\n\nEKF covariance P0=diag([0.15^2,25]); process Q=diag([1e-8,0.1]). Bias EKF P0=diag([0.15^2,25,1]); process Q=diag([1e-8,0.1,1e-5]). Measurement variance R=0.2^2 V^2 (slightly larger than the injected 0.15^2 to allow model discretization error). Joseph covariance updates are used. Jacobian differences: SOC +/-1e-5; filtered current +/-1e-3 A. SOC is bounded 0 to 1; bias is bounded +/-5 A. The derivative evaluation stays within SOC 0.05 to 0.99. These limits stabilize this mid-SOC test; they do not validate empty/full operation.\n\n');
  fprintf(fid,'The observer constants `[E0 K A B R Qinternal Qrated kc tau]` are:\n\n`%s`\n\n',mat2str(p,12));
  fprintf(fid,'Raw dialog values, including inactive/default fields, for every listed block are saved in `Exact_block_parameters.json`. Internal implementation blocks inside linked MathWorks library components are not separately edited.\n');
  f=fopen('Exact_block_parameters.json','w'); fwrite(f,jsonencode(allparams),'char'); fclose(f);
 end
end


