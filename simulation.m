%% MPC SIMULATION
clear all;
close all;
clc;

addpath(genpath('../'));
addpath(genpath('./dataGeneration'));
addpath(genpath('./modelFunctions'));
addpath(genpath('./modelsTraining'));
addpath(genpath('./mpcFunctions'));
addpath(genpath('./savedData'));
addpath(genpath('./utils'));

%% Load parameters, model and setup mpc
% robotModel;
mpcSetup;

x0 = params.x0;
u0 = params.u0;
T = params.T;
Ts = params.Ts;
x_ref = params.x_ref;

nx = nlmpcObj.Dimensions.NumberOfStates;
nu = nlmpcObj.Dimensions.NumberOfInputs;
ny = nlmpcObj.Dimensions.NumberOfOutputs;

p = params.controlHorizon;

B = params.B;
D = params.D;
%% Initialize simulation
mv = u0;
xk = x0;

q_ref = x_ref(1:2)';
theta_ref = x_ref(3:4)';

nSamples = T/Ts;
% so that it is a multiple of p
nSamples = nSamples + (p - mod(nSamples, p)); 

% to record history of simulation
xHistory = zeros(nSamples,nx);
uHistory = zeros(nSamples,nu);
% psiHistory = zeros(nSamples,2);
% psiGP = zeros(nSamples,2);
% psiNN = zeros(nSamples,2);


nloptions = nlmpcmoveopt;

%% Simulate nominal system
dataset = params.dataset;
params.model = gpTrain(dataset);
training = true;
theta_dot_old = [0;0];

for ct = 1:(nSamples/p)
    tau_g = g(q_ref);
    fprintf("t = %.4f\n", ct * Ts * p);
    state = xk(1:4)'
    
    [mv,nloptions,info] = nlmpcmove(nlmpcObj,xk,mv,x_ref,0,nloptions);

    for k=1:p
        t = (ct-1)*p + k;
        xk = info.Xopt(k,:)';
        uk = info.MVopt(k,:)';
        
%         psiHistory(t,:) = nonlinearElasticity(xk, params.K1, params.K2);
%         psiGP(t,:) = gpPredict(xk, params.model);
%         psiNN(t,:) = nnMdl(xk(1:4));
        
        tau = tau_g + mv;
        xk = stateFunctionDT(xk, tau, params);

        xHistory(t,:) = xk';
        uHistory(t,:) = mv';
        
        % Reconstruct elasticity
        if size(dataset,2) < params.datasetDimension
            q = xk(1:2);
            theta = xk(3:4);
            theta_dot = xk(7:8);
            if t > 1
                theta_dot_old = xHistory(t-1, 7:8)';
            end
            theta_ddot = (theta_dot - theta_dot_old)/Ts;
            psi = B*theta_ddot + D*theta_dot - tau;

            dataset(:, end+1) = [q-theta; psi];
        else
            training = false;
        end
    end
    % Retrain GP on the augmented dataset
    if training
        fprintf("Dataset dimension: %d\n", size(dataset, 2));
        disp("Training...");
        tic
        params.model = gpTrain(dataset);
        toc
    end
    
    mv = info.MVopt(end,:)';
    xk = info.Xopt(end,:)';
end
xHistory(end,:) = xk';
uHistory(end,:) = mv';

% tic
% [mv,nloptions,info] = nlmpcmove(nlmpcObj,xk,mv);
% toc
% xHistory = info.Xopt;
% uHistory = info.MVopt;

%% Simulate closed-loop system
% dataset = params.dataset;
% for ct = 1:nSamples
%     tau_g = g(q_ref);
%     fprintf("t = %.4f\n", ct * Ts);
%     state = xk(1:4)'
%     
%     [mv,nloptions,info] = nlmpcmove(nlmpcObj,xk,mv,x_ref,0,nloptions);
%     tau = tau_g + mv;
%     
%     [xk, xk_dot] = stateFunctionDT(xk, tau, params);
%     
%     % Reconstruct elasticity
%     if size(dataset,1) < params.datasetDimension
%         q = xk(1:2);
%         theta = xk(3:4);
%         theta_dot = xk_dot(3:4);
%         theta_ddot = xk_dot(7:8);
%         psi = B*theta_ddot + D*theta_dot - tau;
%         
%         dataset(end+1, :) = [q-theta; psi]';
%         params.model = gpTrain(dataset);
%     end
%     xHistory(ct,:) = xk';
%     uHistory(ct,:) = mv';
% end

%% Plot closed-loop response
figure

t = linspace(0, T, nSamples);
% t = linspace(0, p, p+1);

subplot(2,2,1)
hold on
grid on
plot(t,xHistory(:,1))
yline(q_ref(1), '-');
xlabel('[s]')
ylabel('[rad]')
legend('$q_1$', '$q_1^d$', 'Interpreter', 'latex');
title('First link position')

subplot(2,2,2)
hold on
grid on
plot(t,xHistory(:,2))
yline(q_ref(2), '-');
xlabel('[s]')
ylabel('[rad]')
legend('$q_2$', '$q^d_2$', 'Interpreter', 'latex');
title('Second link position')

subplot(2,2,3)
hold on
grid on
plot(t,xHistory(:,5))
plot(t,xHistory(:,6))
xlabel('[s]')
ylabel('[rad/s]')
legend('$\dot{q}_1$', '$\dot{q}_2$', 'Interpreter', 'latex');
title('Link velocities')
% plot(t,psiHistory(:,1)-psiGP(:,1))
% plot(t,psiHistory(:,2)-psiGP(:,2))
% xlabel('time')
% ylabel('$\psi^{real} - \psi^{pred}$','Interpreter', 'latex')
% legend('$\psi^{err}_1$','$\psi^{err}_2$','Interpreter', 'latex');
% title('Elasticity prediction error (GP)')

subplot(2,2,4)
hold on
grid on
plot(t,uHistory(:,1))
plot(t,uHistory(:,2))
xlabel('[s]')
ylabel('[N]')
legend('$\tau_1$', '$\tau_2$', 'Interpreter', 'latex');
title('Controlled torque')
% plot(t,psiHistory(:,1)-psiNN(:,1))
% plot(t,psiHistory(:,2)-psiNN(:,2))
% ylabel('$\psi^{real} - \psi^{pred}$','Interpreter', 'latex')
% legend('$\psi^{err}_1$','$\psi^{err}_2$','Interpreter', 'latex');
% title('Elasticity prediction error (NN)')