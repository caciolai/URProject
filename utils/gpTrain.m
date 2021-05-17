function gpMdl = gpTrain(dataset)
%TRAINGP Summary of this function goes here
%   Detailed explanation goes here
    
train_data = dataset(1:2,:)';
train_target_1 = dataset(3,:)'; % Joint 1 data to train the model
train_target_2 = dataset(4,:)'; % Joint 2 data to train the model

gpMdl_1 = fitrgp(train_data, train_target_1,...
    'FitMethod','sd',...
    'ActiveSetMethod','entropy',...
    'PredictMethod','sd',...
    'Standardize', true);

gpMdl_2 = fitrgp(train_data, train_target_2,...
    'FitMethod','sd',...
    'ActiveSetMethod','entropy',...
    'PredictMethod','sd',...
    'Standardize', true);

gpMdl = {gpMdl_1, gpMdl_2};

end
