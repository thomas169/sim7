classdef (StrictDefaults) sim7 < matlab.System & ...
        matlab.system.mixin.SampleTime & coder.ExternalDependency & ...
        matlab.system.mixin.CustomIcon & matlab.system.mixin.Propagates 

    properties (Nontunable)
        ts = 10e-3; % Sample Time (s)
        plcIP = '0.0.0.0'; % IP Address
        plcRack = 0; % Rack
        plcSlot = 1; % Slot
        readDB = [1001 1002]; % DB Num
        readPos = [0 0]; % Offset
        readSize = [1 1]; % Bytes
        writeDB = [1001 1002]; % DB Num
        writePos = [0 0];  % Offset
        writeSize = [1 1]; % Bytes
    end
    
    properties(SetAccess = private, Dependent)
        status = 'Unconnected'; % Status
        loaded = 'Unloaded' % Library
    end
    
    properties (Hidden, Constant)
        lib = 'libsnap7';
        include = '/usr/include/'
        header = 'snap7.h'
        areaDB = int32(132);
        wordDB = int32(2);
        port = int32(102);
        errStrLen = 64;
        statusSet = matlab.system.StringSet({'Unconnected','Connected'});
        loadedSet = matlab.system.StringSet({'Unloaded','Loaded'});
    end
    
    properties (Access = private)
        s7Ptr;
        res;
    end
    
    methods
        function obj = sim7(varargin)
            if coder.target('MATLAB')
                warnId = 'SystemBlock:MATLABSystem:ParameterCannotBeDependent';
                warning('OFF',warnId);
            end
            setProperties(obj,nargin,varargin{:})
        end
        
        function loadSnap7(obj)
            warning('OFF','MATLAB:loadlibrary:TypeNotFound');
            obj.libMustBe('Unloaded');
            [~, ~] = loadlibrary(obj.lib,[obj.include obj.header]);
            warning('ON','MATLAB:loadlibrary:TypeNotFound');
        end
        
        function unloadSnap7(obj)
            obj.libMustBe('Loaded');
            unloadlibrary(obj.lib);
        end
        
        function value = get.loaded(obj)
            if libisloaded(obj.lib)
                value = 'Loaded';
            else
                value = 'Unloaded';
            end
        end
        
        function set.loaded(~,~)
            % Stub required for use in Simulink
        end
        
        function set.status(~,~)
            % Stub required for use in Simulink
        end
        
        function value = get.status(obj)
            if obj.s7Ptr > 0
                value = 'Connected';
            else
                value = 'Unconnected';
            end
        end
    end
    
    methods(Static)
        
        function bName = getDescriptiveName(~)
            bName = 'libsnap7';
        end

        function tf = isSupportedContext(~)
            tf = true;
        end
        
        function updateBuildInfo(buildInfo, buildConfig)
            [~, ~, libExt, ~] = buildConfig.getStdLibInfo();
            libName = ['libsnap7' libExt];
            libPath = '/usr/lib/'; % **** CHANGE LIBPATH AS NEEDED ****
            if exist([libPath libName], 'file') ~= 2
                error('Library missing')
            end
            buildInfo.addLinkObjects(libName,libPath,'',true,true,'');
        end
    end
    
    methods (Access = private)
        
        function value = lastError(obj)
            obj.libMustBe('Loaded');
            obj.connMustBe('Connected');
            errStr = repmat(' ',1,obj.errStrLen);
            errNo = 0;
            [resA, errNo] = calllib(obj.lib,'Cli_GetLastError',...
                obj.s7Ptr, errNo);
            [resB, errStr] = calllib(obj.lib,'Cli_ErrorText',errNo,...
                errStr,obj.errStrLen-1);
            if resA == 0 && resB == 0
                value = strtrim(errStr);
            else
                warning('Something went wrong')
                obj.res = max(resA,resB);
            end
        end
        
        function libMustBe(obj,varargin)
            if nargin == 1
               test = 'Unloaded';
            else
               test = varargin{1};
            end
             if ~strcmp(obj.get.loaded,test)
                 error(['Library is ' upper(test) ' check failed'])
             end
        end
        
        function connMustBe(obj,varargin)
            if nargin == 1
               test = 'Unconnected';
            else
               test = varargin{1};
            end
            if ~strcmp(obj.get.status,test)
                error(['Snap7 is ' upper(test) ' check failed'])
            end
        end
        
        function create(obj)
            % connect standalone code
            obj.libMustBe('Loaded');
            obj.connMustBe('Unconnected');
            
            obj.s7Ptr = calllib(obj.lib,'Cli_Create');
            
            if ~(obj.s7Ptr > 0)
                error('Could not create s7 object!')
            end
        end
        
        function connect(obj)
            % connect standalone code
            obj.libMustBe('Loaded');
            obj.connMustBe('Unconnected');
            
            obj.res = calllib(obj.lib,'Cli_ConnectTo', obj.s7Ptr,...
                obj.plcIP, obj.plcRack, obj.plcSlot);
            
            if obj.res ~= 0 
                obj.destroy();
                error('Couldn''t connect to PLC')
            end
        end
        
        function destroy(obj)
            obj.libMustBe('Loaded');
            obj.connMustBe('Connected');
            calllib(obj.lib,'Cli_Destroy',obj.s7Ptr);
            obj.s7Ptr = [];
        end

        function disconnect(obj)
            % disconnect standalone code
            obj.libMustBe('Loaded');
            obj.connMustBe('Connected');
            
            calllib(obj.lib,'Cli_Destroy',obj.s7Ptr);
            obj.s7Ptr = [];
        end
        
        function data = cpuInfo(obj)
            data = struct([]);
            [obj.res, data] = calllib(obj.lib,'Cli_GetCpuInfo',obj.s7Ptr, data);
        end
        
        function data = s7read(obj)
            % disconnect standalone code
            obj.libMustBe('Loaded');
            obj.connMustBe('Connected');
            idx = 1;
            data = zeros(sum(obj.readSize),1,'uint8');
            for n = 1 : numel(obj.readDB)
                [obj.res, plcData] = calllib(obj.lib,'Cli_ReadArea',obj.s7Ptr,...
                    obj.areaDB,obj.readDB(n),obj.readPos(n),obj.readSize(n),...
                    obj.wordDB, data(idx));
                data(idx:idx+obj.readSize(n)-1) = plcData;
                idx = idx + obj.readSize(n);
            end 
        end
        
        function s7write(obj,data)
            % disconnect standalone code
            obj.libMustBe('Loaded');
            obj.connMustBe('Connected');
            idx = 1;
            for n = 1 : numel(obj.writeDB) 
                obj.res = calllib(obj.lib,'Cli_WriteArea',obj.s7Ptr,...
                    obj.areaDB,obj.writeDB(n),obj.writePos(n),obj.writeSize(n),...
                    obj.wordDB,data(idx));
                idx = idx + obj.writeSize(n);
            end
        end
    end

    methods(Access = protected)
        
        function varargout = stepImpl(obj,varargin)
            % snap7 step get inputs -> write to plc / read plc -> set
            % to the outputs.
            
            if coder.target('MATLAB')
                matData = [];
                idx = 1;
                
                % Gather inputs
                for n = 1 : numel(varargin)
                    matData = [matData ; varargin{n}];
                end
               
                % PLC IO calls
                obj.s7write(matData);
                plcData = obj.s7read();
                
                % Assign outputs
                for n = 1 : nargout
                    varargout{n} = plcData(idx : idx + obj.readSize(n) - 1);
                    idx = idx + obj.readSize(n);
                end
                
                return;
            end
            
            nWrite = numel(obj.writeDB);
            nRead = numel(obj.readDB);
            nMax = max([obj.readSize obj.writeSize]);
            snap7Data = coder.nullcopy(uint8(zeros(nMax,1)));
            coder.varsize('snap7Data');
            
            for n = 1 : nWrite
                snap7Data = varargin{n};
                obj.res = coder.ceval('Cli_WriteArea', obj.s7Ptr, obj.areaDB,...
                    int32(obj.writeDB(n)), int32(obj.writePos(n)),...
                    int32(obj.writeSize(n)), obj.wordDB, coder.ref(snap7Data));
            end
            
            for n = 1 : nRead
                obj.res = coder.ceval('Cli_ReadArea', obj.s7Ptr, obj.areaDB,...
                    int32(obj.readDB(n)), int32(obj.readPos(n)),...
                    int32(obj.readSize(n)), obj.wordDB, coder.ref(snap7Data));
                varargout{n} = snap7Data(1:obj.readSize(n));
            end
            
        end

        function setupImpl(obj)
            % Perform one-time calculations, such as computing constants
            
            if ~coder.target('MATLAB')
                obj.res = int32(0);
                addr = [obj.plcIP char(0)];
                rack = int32(obj.plcRack);
                slot = int32(obj.plcSlot);
                obj.s7Ptr = coder.opaque('S7Object', 'Cli_Create()','HeaderFile',obj.header);
                obj.res = coder.ceval('Cli_ConnectTo',obj.s7Ptr, addr, rack, slot);
                if obj.res == 0 
                   obj.status = 'Connected';
                end
            elseif ~obj.isInMATLABSystemBlock
                obj.connect();
            end
        end

        function releaseImpl(obj)
            % Release resources, such as file handles
            if ~coder.target('MATLAB')
                coder.ceval('Cli_Destroy', coder.ref(obj.s7Ptr));
                obj.status = 'Unconnected';
            elseif ~obj.isInMATLABSystemBlock
                obj.disconnect();
            end
        end
        
        function icon = getIconImpl(obj)
            % Define icon for System block
            icon = sprintf(['snap7 PLC\nIP: %s\nRack: %d Slot:%d\n'...
                'Ts: %gms'], obj.plcIP, obj.plcRack,...
                obj.plcSlot, 1000*obj.ts);
        end

        function varargout = getInputNamesImpl(obj)
            % Return input port names for System block
            nIn = numel(obj.writeDB);
            varargout = cell(1,nIn);
            for k = 1:nIn
                db = obj.writeDB(k);
                startIdx = obj.writePos(k);
                endIdx = obj.writePos(k) + obj.writeSize(k) - 1;
                varargout{k} = sprintf('%d[%u:%d]',db,startIdx,endIdx);
            end
        end
        
        function varargout = getOutputNamesImpl(obj)
            % Return output port names for System block
            nOut = numel(obj.readDB);
            varargout = cell(1,nOut);
            for k = 1:nOut
                db = obj.readDB(k);
                startIdx = obj.readPos(k);
                endIdx = obj.readPos(k) + obj.readSize(k) - 1;
                varargout{k} = sprintf('%d[%u:%d]',db,startIdx,endIdx);
            end
        end
        
        function flag = isDiscreteStateSpecificationMutableImpl(~)
            % False if state cannot change size, type, or complexity.
            flag = false;
        end

        function validateInputsImpl(~,varargin)
            % Validate inputs to the step method at initialization
            for n = 1 : nargin - 1
                if ~any(strcmp(class(varargin{n}),{'int8','uint8'}))
                    disp('Input should be byte sized (int8 / uint8)');
                end
            end
        end

        function num = getNumInputsImpl(obj)
            % Define total number of inputs
            num = numel(obj.writeDB);
        end

        function num = getNumOutputsImpl(obj)
            % Define total number of outputs
            num = numel(obj.readDB);
        end

        function varargout = getOutputSizeImpl(obj)
            % Return size for each output port
            varargout = cell(1,nargout);
            for n = 1 : nargout
                varargout{n} = [obj.readSize(n) 1];
            end
        end

        function varargout = getOutputDataTypeImpl(~)
            % Return data type for each output port
            varargout = cell(1,nargout);
            for n = 1 : nargout
                varargout{n} = 'uint8'; 
            end
        end

        function varargout = isOutputComplexImpl(~)
            % Return true for each output port with complex data
            varargout = cell(1,nargout);
            for n = 1 : nargout
                varargout{n} = false;
            end
        end

        function varargout = isOutputFixedSizeImpl(~)
            % Return true for each output port with fixed size
            varargout = cell(1,nargout);
            for n = 1 : nargout
                varargout{n} = true;
            end
        end
        
        function sts = getSampleTimeImpl(obj)
            % Define sample time type and parameters
            if obj.ts <= 0
                sts = obj.createSampleTime("Type", "Inherited");
            else
                sts = obj.createSampleTime("Type", "Discrete","SampleTime", obj.ts);
            end
        end
    end

    methods(Access = protected, Static)
        
        function header = getHeaderImpl
            % Define header panel for System block dialog
            header = matlab.system.display.Header(mfilename('class'), ...
                'Title','sim7','Text',['Read and write to a PLC '...
                'using the snap7 library. Inputs and outputs must be '...
                'byte sized arrays. Codegen only. Linux only. Requires '...
                'modified snap7.h file.']);
        end

        function group = getPropertyGroupsImpl
            % Define property section(s) for System block dialog
            block = matlab.system.display.SectionGroup('Title','General',...
                'PropertyList',{'ts', 'status', 'loaded'});
            plc = matlab.system.display.SectionGroup('Title','PLC',...
                'PropertyList',{'plcIP','plcRack','plcSlot'});
            write = matlab.system.display.SectionGroup('Title','Write',...
                'PropertyList',{'writeDB','writePos','writeSize'});
            read = matlab.system.display.SectionGroup('Title','Read',...
                'PropertyList',{'readDB', 'readPos','readSize'});
            group = [block plc write read];
        end
        
        function flag = showSimulateUsingImpl
            % Return false if simulation mode hidden in System block dialog
            flag = false;
        end
    end
end %#ok<*AGROW>
