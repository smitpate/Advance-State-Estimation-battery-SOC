% Run in MATLAB R2023b. Normal use does not rebuild the saved model.
assert(strcmp(version('-release'),'2023b'),'Please use MATLAB R2023b.');
folder=fileparts(mfilename('fullpath')); cd(folder); addpath(folder);
m='EV_Battery_Discharge_Regen';
if ~isfile([m '.slx']), build_battery_scopes; end
load_system(m); open_system(m); out=sim(m);
save('run_data.mat','out'); validate_battery_scopes(out);
open_system([m '/Battery V I SOC']);
open_system([m '/Discharge and regeneration']);
open_system([m '/SOC comparison']);
fprintf('Scopes are populated. Double-click Sensor bias estimate for the fourth Scope.\n');
