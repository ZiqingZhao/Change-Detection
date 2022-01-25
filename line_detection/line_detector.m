function Line = line_detector(IM)
% Line segment detection using direct method.
% ****************** Version 1.0 Note ***********************
% References: 
% 1. P. Kahn, L. Kitchen and E.M. Riseman, A fast line finder for
% vision-guided robot navigation, PAMI nov. 1990, pp 1098-1102.
% 2. X. Lebegue and J.K. Aggarwal, Significant line segments for an indoor
% mobile robot. PAMI, Dec. 1993, pp 801-815.
% 3. Jana Kosecka and Wei Zhang, Video Compass, IJCV 2002.
% Author: Allen Y. Yang, August, 2003. UIUC
%
% ****************** Version 1.1 Note **********************
% Add line segment extension function to detect short line disconnections
% Author: Allen Y. Yang, August, 2003. UIUC

% Pre-Processing to get magnitude and direction information from raw image
if size(IM,3)>1
    IM = rgb2gray(IM);
end

gaussionFilter = fspecial('gaussian',[4,4],2);
IM = imfilter(IM,gaussionFilter);
IM = im2double(IM);
[Ix, Iy] = sobel(IM);
[magnitude, direction]=GradientQuantization(Ix,Iy,'canny');

[h w] = size(magnitude);
limit = floor(w*0.04);
element8 = [-1 -1; -1 0; -1 1; 0 -1; 0 1; 1 -1; 1 0; 1 1];
element24= [-2 -2; -2 -1; -2 0; -2 1; -2 2; -1 -2; -1 -1; -1 0; -1 1; -1 2; 0 -2; 0 -2; 0 1; 0 2; 1 -2; 1 -1; 1 0; 1 1; 1 2; 2 -2; 2 -1; 2 0; 2 1; 2 2];
N=0;    L = [];

% Step 1, Form line support regions
for x=3:h-2                     % Avoid boundary effect
    for y=3:w-2
        if magnitude(x,y)>0     % new start point of a possible line support region
            % Init starting point
            region = [];
            region(1,1:2)=[x y]; 
            mag = magnitude(x,y);
            dir = direction(x,y);
            magnitude(x,y)=0;
            head = 1; tail = 1;
            while (tail>=head)
                % inner loop search for the max region with specific direction
                % and magnitude.
                while (tail>=head)
                    % search new connected components (CCA method)
                    for i=1:24   
                        xx = region(head,1) + element24(i,1);
                        yy = region(head,2) + element24(i,2);
                        if (xx>2)& (yy>2) & (xx<=h-2) & (yy<=w-2) & (magnitude(xx,yy)>0) & (abs(magnitude(xx,yy)-mag)<1.5) & ((abs(direction(xx,yy)-dir)<=1) | (abs(direction(xx,yy)-dir)==15))
                            tail = tail + 1;
                            region(tail,1:2)=[xx yy];
                            magnitude(xx,yy) = 0;
                        end
                    end
                    head = head +1;
                end
                % outer loop search for the possible extension beyond the
                % end point.
                dir = direction(region(tail,1),region(tail,2));
                for i=-5:5
                    for j=-5:5
                        xx = region(tail,1)+i;
                        yy = region(tail,2)+j;
                        if (xx>2)& (yy>2) & (xx<=h-2) & (yy<=w-2) & (magnitude(xx,yy)>0) & ( direction(xx,yy)==dir )
                            % extend the line support region with new start
                            % point (xx,yy)
                            tail = tail + 1;
                            region(tail,1:2)=[xx yy];
                            mag = magnitude(xx,yy);
                            magnitude(xx,yy)=0;
                            break;
                        end
                    end
                    if (tail==head)
                        break;
                    end
                end
            end
            if tail>limit
% Step 2: Fit line parameters of the regions
                % Visualize the support region
%                 hold on;
%                 for i=1:tail
%                     plot(region(i,2),region(i,1),'bo'); % The plot coordinate is (y,x) starting from the same upper-left
%                 end                
%                 Calculate the eigenvalues of the line parameter matrix
%                 When we process the coordinates in Matlab, need to
%                 remember it array starts from (1,1), image from (0,0)
%                 The following codes compensate the difference.
                for i=1:tail
                    region(i,1)=region(i,1)-1;
                    region(i,2)=region(i,2)-1;
                end
                % The above codes are only necessary under Matlab.
                
                xybar=sum(region)/tail;
                xytilt=region - repmat(xybar,tail,1);
                D = zeros(2,2);
                for i=1:tail
                    xx = xytilt(i,1)*xytilt(i,1);
                    xy = xytilt(i,1)*xytilt(i,2);
                    yy = xytilt(i,2)*xytilt(i,2);
                    D=D + [xx xy; xy yy];
                end
                [Vector Value] = eig(D); %The eigenvector corresponding to the larger eigenvalue is Vector(:,2)
                theta = atan2(Vector(2,2), Vector(1,2));    
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %            .-----------------------------> y     %
                %            |   /                                 %
                %            |  /                                  %
                %            | /                                   %
                %            |/                                    %
                %            |) theta                              %
                %            V x                                   %
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                sinTheta = sin(theta);
                cosTheta = cos(theta);
                dist = xybar(1)*sinTheta-xybar(2)*cosTheta;
                
                % Calculate end points by projecting two end pixels back to
                % the line equation.
                endpoints(:,1) = PointProjToLine(region(1,:)',theta,dist);
                endpoints(:,2) = PointProjToLine(region(tail,:)',theta,dist);
                
                % Step 4, finally register the line associated to the two
                % points. Note that the line is uncalibrated.
                N=N+1;
                Line(1:2,N)=endpoints(:,1);
                Line(3:4,N)=endpoints(:,2);
                Line(5:6,N)=[theta; dist];
            end
        end
    end
end