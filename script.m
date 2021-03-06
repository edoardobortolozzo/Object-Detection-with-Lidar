clear vars;
close all;
%% DATA LOADING
dataMainDir = './';
configID = '1';
fullFolderPath = fullfile(dataMainDir,sprintf('./Config%s',configID));
fileList = dir(fullFolderPath);
nameList = {fileList.name};
nameList = nameList(3:end);
% fileDateTime = '2019-12-12-15-07-21';
fileName = nameList{endsWith(nameList,'_Velodyne-VLP-16-Data.pcap')};
fullFilePath = fullfile(fullFolderPath,fileName);

fileList = dir(fullFilePath);

deviceModel = 'VLP16';

data = velodyneFileReader(fullFilePath,deviceModel);

%% COLOR LABELS
% Define labels to use for segmented points
colorLabels = [...
    0      0.4470 0.7410; ... % Unlabeled points, specified as [R,G,B]
    0.4660 0.6740 0.1880; ... % Ground points
    0.9290 0.6940 0.1250; ... % Ego points
    0.6350 0.0780 0.1840];    % Obstacle points


% Define indices for each label
colors.Unlabeled = 1;
colors.Ground    = 2;
colors.Ego       = 3;
colors.Obstacle  = 4;

%% VEHICLE CREATION
% TODO:
% MUST CHANGE WITH VEHICLE DIMENSIONS (length, width, height)
length = 1.5;
width = 2.2;
height = 1;
vehicleDims = vehicleDimensions(length, width, height); % Typical vehicle 4.7m by 1.8m by 1.4m

% lidar's position relative to the vehicle
mountLocation = [...
    vehicleDims.Length/2 - vehicleDims.RearOverhang, ... % x
    0, ...                                               % y
    vehicleDims.Height];                                 % z
sensorLocation  = [0, 0, 0]; % Sensor is at the center of the coordinate system

%% PLAYER
%room
xlimits = [-5 3];
ylimits = [-4 5];
zlimits = [-2 2];

%object
% xlimits = [-0.5 0];
% ylimits = [0.65 1];
% zlimits = [-0.2 0.2];

%room no walls
% xlimits = [-4.3 1.8];
% ylimits = [-2.5 3.3];
% zlimits = [-2 2];


player = pcplayer(xlimits,ylimits,zlimits);
xlabel(player.Axes,'X (m)');
ylabel(player.Axes,'Y (m)');
zlabel(player.Axes,'Z (m)');
minDistance = 0.1;
data.CurrentTime = data.EndTime - seconds(10);
% while(hasFrame(data) && player.isOpen() && (data.CurrentTime < data.CurrentTime + seconds(10)))
%     ptCloudObj = readFrame(data);
% %     ptCloudSeg = pcsegdist(ptCloudObj,minDistance);
% %     pcshow(ptCloudObj.Location,ptCloudSeg);
% %     view(player,ptCloudObj.Location,ptCloudSeg);
%     view(player,ptCloudObj.Location,ptCloudObj.Intensity);
%     pause(10);
% end

% Set the colormap
colormap(player.Axes, colorLabels)

% while(hasFrame(data) && player.isOpen() && (data.CurrentTime < data.CurrentTime + seconds(10)))
    %% POINT CLOUD CRATION
    ptCloudTemp = readFrame(data);
    points = struct();
    
    % TODO: change radius
    radius          = 2.35; % meters
    nearbyPoints = findNeighborsInRadius(ptCloudTemp, ...
        sensorLocation, radius);                                            %cerco i punti vicini
    ptCloudObj = select(ptCloudTemp, nearbyPoints , 'OutputSize', 'full');  %restringo area ricerca per qualsiasi cosa
    
    %% POINTS GROUPING - CAR
    zlidar=0.12;                                                            %posizione relativa del lidar rispetto alla scrivania
    points.EgoPoints = helperSegmentEgoFromLidarData(ptCloudObj, vehicleDims, mountLocation,zlidar);
    closePlayer = false;

    %% POINTS GROUPING - GROUND
    elevationDelta = 5;
    points.GroundPoints = segmentGroundFromLidarData(ptCloudObj, 'ElevationAngleDelta', elevationDelta);

    %% POINTS GROUPING - OBSTACLES
   nonEgoGroundPoints = ~points.EgoPoints & ~points.GroundPoints;
 %    nonEgoGroundPoints = ~points.GroundPoints;
    ptCloudSegmented = select(ptCloudObj, nonEgoGroundPoints, 'OutputSize', 'full');

    

    points.ObstaclePoints = findNeighborsInRadius(ptCloudSegmented, ...
        sensorLocation, radius);


    %% CLASS TRY
    disp("Algoritmo basato su pcsegdist");
    tic
    boxes = getBoundingBoxes(ptCloudSegmented, 0.1, 20, 1.5, -1.5);
    toc
    [s1,s2]=size(boxes);
    disp(['Numero clusters: ' num2str(s2)]);
    disp(newline);
    disp("Algoritmo basato su k-means (possibili warning per lentezza)")
    tic
    boxes2 = getBoundingBoxes2(ptCloudSegmented);
    toc
    [b1,b2]=size(boxes2);
    disp(['Numero clusters: ' num2str(b2)]);
    disp(newline);
    
    %% MSE
%      manualbox1=[-0.3517; 0.7899; -0.1160; -0.1796; 0.9215; -0.0151];
%      manualbox2=[-0.6000; -2.3956; -0.1269; -0.4465; -2.2432; -0.0413];
%      manualbox3=[-0.2046; -2.3018; -0.1211; -0.1295; -2.2205; 0.0397];
     manualbox11=[-0.3517; 0.7899; -0.1383; -0.1796; 0.9215; -0.0151];
     manualbox22=[-0.6000; -2.3956; -0.1832; -0.4465; -2.2432; -0.0413];
     manualbox33=[-0.2046; -2.3018; -0.1832; -0.1295; -2.2205; 0.0397];
     manualbox1=single(manualbox11);
     manualbox2=single(manualbox22);
     manualbox3=single(manualbox33);
     
     
     
     mse=[10 10 10;10 10 10];
     for i=1:s2
      
        err1=immse(boxes(:,i),manualbox1);
        err2=immse(boxes(:,i),manualbox2);
        err3=immse(boxes(:,i),manualbox3);
        if err1<mse(1,1)
           mse(1,1)=err1;
        end
        if err2<mse(1,2)
           mse(1,2)=err2;
        end
        if err3<mse(1,3)
           mse(1,3)=err3;
        end        
     end
     for i=1:b2
        err1=immse(boxes2(:,i),manualbox11);
        err2=immse(boxes2(:,i),manualbox22);
        err3=immse(boxes2(:,i),manualbox33);
        if err1<mse(2,1)
           mse(2,1)=err1;
        end
        if err2<mse(2,2)
           mse(2,2)=err2;
        end
        if err3<mse(2,3)
           mse(2,3)=err3;
        end        
     end 
    disp('Mse: ');
    disp(mse);
    
    
    %% VISUALIZZAZIONE
    % Visualize the segmented obstacles
%     [a,b,c]=size(ptCloudObj.Location);
%     prova=ptCloudObj.Location;
%     for x = 1:a
%         for y = 2:b
%             for z = 1:c
%                 prova(x,y,z)=0;
%             end
%         end
%     end
    
    % Visualize segmented parts
    helperUpdateView(player, ptCloudTemp, points, colors, closePlayer);
    
    % Visualize boxes
    p=ptCloudTemp.Location;
    x=p(:,:,1);
    y=p(:,:,2);
    z=p(:,:,3);
    [a,b]=size(x);
    for i=1:a
        for j=1:b
             if y(i,j)>3.3 || y(i,j)<-2.5 || x(i,j)<-4.3 || x(i,j)>1.8
 %          if y(i,j)>5 || y(i,j)<-4 || x(i,j)<-5 || x(i,j)>3
                x(i,j)=nan;
                y(i,j)=nan;
                z(i,j)=nan;
            end
        end
    end
    
    %preparazione figure
    figure('name', 'Risultati pcsegdist', 'NumberTitle', 'off');
    plot3(x,y,z,'.','Markersize',3,'Color','[0 0.4470 0.7410]');
    xlabel('X (m)');
    ylabel('Y (m)');
    zlabel('Z (m)');
    hold on;

    %plotting boxes pcsegdist
    for k=1:s2
        X = [boxes(1,k),boxes(4,k),boxes(4,k),boxes(1,k),boxes(1,k)];
        Y = [boxes(2,k),boxes(2,k),boxes(5,k),boxes(5,k),boxes(2,k)];
        Z1 = [boxes(3,k),boxes(3,k),boxes(3,k),boxes(3,k),boxes(3,k)];
        Z2 = [boxes(6,k),boxes(6,k),boxes(6,k),boxes(6,k),boxes(6,k)];
        plot3(X,Y,Z1,'Color','[0.6350 0.0780 0.1840]');
        plot3(X,Y,Z2,'Color','[0.6350 0.0780 0.1840]');
        plot3([X(1:4);X(1:4)],[Y(1:4);Y(1:4)],[Z1(1);Z2(1)],'Color','[0.6350 0.0780 0.1840]');

    end

    %preparazione figure
    figure('name', 'Risultati k-means', 'NumberTitle', 'off');
    plot3(x,y,z,'.','Markersize',3,'Color','[0 0.4470 0.7410]');
    xlabel('X (m)');
    ylabel('Y (m)');
    zlabel('Z (m)');
    hold on;
    
    %plotting boxes k-means
    for k=1:b2
        X = [boxes2(1,k),boxes2(4,k),boxes2(4,k),boxes2(1,k),boxes2(1,k)];
        Y = [boxes2(2,k),boxes2(2,k),boxes2(5,k),boxes2(5,k),boxes2(2,k)];
        Z1 = [boxes2(3,k),boxes2(3,k),boxes2(3,k),boxes2(3,k),boxes2(3,k)];
        Z2 = [boxes2(6,k),boxes2(6,k),boxes2(6,k),boxes2(6,k),boxes2(6,k)];
        plot3(X,Y,Z1,'Color','[0.6350 0.0780 0.1840]');
        plot3(X,Y,Z2,'Color','[0.6350 0.0780 0.1840]');
        plot3([X(1:4);X(1:4)],[Y(1:4);Y(1:4)],[Z1(1);Z2(1)],'Color','[0.6350 0.0780 0.1840]');

    end

%     pause(0.1);
% end