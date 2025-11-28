
modelName = 'goertzel_algorithm4';
open_system(modelName);

% Define parameters
N = 1000;  % Block length (number of samples to process)
k = 10;   % Target DFT bin
fs = 1000000; % Sample frequency (Hz)
Ts = 1/fs; % Sample time period
fcarrier = 10000; % Carrier frequency (Hz)
ac = 128; % Carrier amplitude within +/- ac

% Calculate coefficient
omega = 2*pi*k/N;
coeff = 2*cos(omega);

fprintf('\n=== Goertzel Simulink Model ===\n');
fprintf('Model: %s.slx\n', modelName);
fprintf('Block size: N = %d samples\n', N);
fprintf('Target bin: k = %d (frequency = %.2f Hz)\n', k, k*fs/N);
fprintf('Sample frequency (Hz) = %.2f \n', fs);
fprintf('Carrier frequency (Hz) = %.2f \n', fcarrier);
fprintf('Carrier amplitude  = +/- %.2f \n', ac);
fprintf('\nFeatures:\n');
fprintf('- Processes %d-sample blocks\n', N);
fprintf('- Automatic reset every N samples\n');
fprintf('- Output computed at end of each block\n');
