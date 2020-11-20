%**************************************************************************
%       SeqConverter.m
%      ================
% CREATED: June 18, 2016
% MODIFIED: August 20, 2020
% EDITOR: XYZ
%
% DESCRITION:
%   Read single or multiple -seq format file and convert into any type of image
%
% NOTES:
%   - The default type and bits of image is -tiff and uint8.
%     (If you have the other customized options, you can modify this program.)
%   - When image is being rewritten, you cannot open to the directory including
%     the file. Because the Explorer will update its available information and
%     momentarily block the file from being rewritten.
%
% VERSION: 2.0
%
% ENVIRONMENT:
%   - WIN10 Enterprise (64-bit)
%   - MATLAB R2019b Update 6
%**************************************************************************
close all, clear all
tic

%%
% retrieve files
[fname,fpath] = uigetfile('*.seq','MultiSelect','on');

if (iscell(fname) ~= 1)
    fname = cellstr(fname);
end

%% .seq format files convert into .tiff
for nFile = 1:length(fname)
    disp(['Convering -seq into -tiff...(',num2str(nFile),'/',num2str(length(fname)),')']);
    
    % define expression of inputname and outputname
    inputname = strcat(fpath,fname{nFile});
    outputname = [fpath,strrep(fname{nFile},'.seq',''),'.tif'];
    
    fid = fopen(inputname,'r','ieee-be');
    
    % read header
    OFB = {28,1,'long'};
    fseek(fid,OFB{1},'bof');
    headerInfo.Version = fread(fid,OFB{2},OFB{3},'ieee-le');
    
    OFB = {32,4/4,'long'};
    fseek(fid,OFB{1},'bof');
    headerInfo.HeaderSize = fread(fid,OFB{2},OFB{3},'ieee-le');
    if  (headerInfo.Version>=5)
        headerInfo.HeaderSize = 8192;
    end
    
    OFB = {592,1,'long'};
    fseek(fid,OFB{1},'bof');
    DescriptionFormat = fread(fid,OFB{2},OFB{3},'ieee-le')';
    OFB = {36,512,'ushort'};
    fseek(fid,OFB{1},'bof');
    headerInfo.Description = fread(fid,OFB{2},OFB{3},'ieee-le')';
    if (DescriptionFormat==0)
        headerInfo.Description = native2unicode(headerInfo.Description);
    else
        headerInfo.Description = char(headerInfo.Description);
    end
    
    OFB = {548,24,'uint32'};
    fseek(fid,OFB{1}, 'bof');
    tmp = fread(fid,OFB{2},OFB{3},0,'ieee-le');
    headerInfo.ImageWidth = tmp(1);
    headerInfo.ImageHeight = tmp(2);
    headerInfo.ImageBitDepth = tmp(3);
    headerInfo.ImageBitDepthReal = tmp(4);
    headerInfo.ImageSizeBytes = tmp(5);
    vals = [0,100,101,200:100:600,610,620,700,800,900];
    fmts = {'Unknown','Monochrome','Raw Bayer','BGR','Planar','RGB',...
        'BGRx','YUV422','YUV422_20','YUV422_PPACKED','UVY422','UVY411','UVY444'};
    headerInfo.ImageFormat = fmts{vals == tmp(6)};
    
    OFB = {572,1,'ushort'};
    fseek(fid,OFB{1},'bof');
    headerInfo.AllocatedFrames = fread(fid,OFB{2},OFB{3},'ieee-le');
    
    %
    OFB = {580,1,'ulong'};
    fseek(fid,OFB{1},'bof');
    headerInfo.TrueImageSize = fread(fid,OFB{2},OFB{3},'ieee-le');
    
    %
    OFB = {584,1,'double'};
    fseek(fid,OFB{1},'bof');
    headerInfo.FrameRate = fread(fid,OFB{2},OFB{3},'ieee-le');
    
    %
    OFB = {620,1,'uint8'};
    fseek(fid,OFB{1},'bof');
    headerInfo.Compression = fread(fid,OFB{2},OFB{3},'ieee-le');
    switch headerInfo.ImageBitDepthReal
        case 8
            bitstr = 'uint8';
        case {10,12,14,16}
            bitstr = 'uint16';
    end
    
    % read and write image
    numPixels = headerInfo.ImageWidth * headerInfo.ImageHeight;
    imgOut = zeros(headerInfo.ImageHeight,headerInfo.ImageWidth);
    for nFrame = 0:headerInfo.AllocatedFrames-1
        fseek(fid,headerInfo.HeaderSize + nFrame * headerInfo.TrueImageSize,'bof');
        tmp = fread(fid,numPixels,bitstr,'ieee-le');
        imgOut = transpose(reshape(tmp,headerInfo.ImageWidth,headerInfo.ImageHeight));
        if strcmp(bitstr,'uint8')
            imwrite(uint8(imgOut),outputname,'Compression','none','WriteMode','append');
        else
            imwrite(uint16(imgOut),outputname,'Compression','none','WriteMode','append');
        end
    end
    fclose(fid);
    
    save(['headerInfo_',strrep(fname{nFile},'.seq',''),'.mat'],'headerInfo')
end
disp('Done.')
