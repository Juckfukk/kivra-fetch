






class puppeteer {


        __new(debugPort:= 9222,dataDir := "",windowsize := "860x531",url := "about:blank",domains := "",console := true,exe := "chrome.exe",flags := "")
        {

            insts := this.checkPort()
            this.debugPort  := (insts.HasKey(debugPort) ? (debugPort+1) : debugPort)
            this.dataDir    := (dataDir = "" ? A_AppData "\ahkpuppeteer\" StrReplace(exe,".exe") "\" debugPort : dataDir)
            this.domains    := (domains = "" ? ["Console","Page"] : domains ) ;["Console","Debugger","Page","DOM","Runtime","Inspector","Network"]
            this.exe        := exe
            this.flags      := flags
            this.windowsize := windowsize
            this.url        := url 
            this.messages   := {}
            this.responses  := {}
            this.connected  := false
            this._console   := (console ? true : false)
            this._id := 0
            ;this.killWindow()
            
            ;if (l = "")
            

            this.launch()

            ;this.runChrome()

            
            
        }
        checkPort()
        {
                static Needle := "--remote-debugging-port=(\d+)"
                Out := {}
                for Item in ComObjGet("winmgmts:").ExecQuery("SELECT * FROM Win32_Process"){
                        if RegExMatch(Item.CommandLine, Needle, Match)
                        Out[Match1] := Item.CommandLine
                }
                ;Array_Gui(out)
                return Out.MaxIndex() ? Out : False   
        }
        keepAlive()
        {
            return
            if (this.connected){
              r :=  this.call("Browser.getVersion")
              r := JSON.DUMP(r)
              if (instr(r,"error : timeout")){
                  this.Disconnect()
                  return
              } else {
                KeepAlive := ObjBindMethod(this,"keepAlive")
                SetTimer, % keepAlive, -95000
              }

            }
        }
        launch()
        {


            /*

                defaultArgs(options: BrowserLaunchArgumentOptions = {}): string[] {
                    const chromeArguments = [
                    '--disable-background-networking',
                    '--enable-features=NetworkService,NetworkServiceInProcess',
                    '--disable-background-timer-throttling',
                    '--disable-backgrounding-occluded-windows',
                    '--disable-breakpad',
                    '--disable-client-side-phishing-detection',
                    '--disable-component-extensions-with-background-pages',
                    '--disable-default-apps',
                    '--disable-dev-shm-usage',
                    '--disable-extensions',
                    '--disable-features=Translate,BackForwardCache',
                    '--disable-hang-monitor',
                    '--disable-ipc-flooding-protection',
                    '--disable-popup-blocking',
                    '--disable-prompt-on-repost',
                    '--disable-renderer-backgrounding',
                    '--disable-sync',
                    '--force-color-profile=srgb',
                    '--metrics-recording-only',
                    '--no-first-run',
                    '--enable-automation',
                    '--password-store=basic',
                    '--use-mock-keychain',
                    // TODO(sadym): remove '--enable-blink-features=IdleDetection'
                    // once IdleDetection is turned on by default.
                    '--enable-blink-features=IdleDetection',
                    '--export-tagged-pdf',
                    ];
            */

            wsize := this.windowsize
            if !(wsize = ""){
                    s := strSplit(wsize,"x")
                wsize :=  s[1] "," s[2]
            }  
            flags :=    [this.exe
                        ,"--remote-debugging-port=" 	.   this.debugPort
                        ,"--user-data-dir="         	.   this.dataDir
                        ,"--app="""                   	.   this.url	. """"
                        ,"--bwsi"
                        ,"--new-window"
                        ,"--window-size=" wsize
                        ,"--disable-extensions"
                        ,"--no-first-run"
                        ,"--disable-sync"
                        ,"--disable-default-apps"
                        ,"--disable-client-side-phishing-detection"
                        ,"--disable-breakpad"
                        ,"--disable-prompt-on-repost"
                        ,"--disable-features=Translate,BackForwardCache"
                        ,"--disable-renderer-backgrounding"
                        ,"--disable-backgrounding-occluded-windows"]
            for k,v in this.flags
            flags.push(v)
            for i in flags
            cm .= flags[i] . " "              
            cm := trim(cm)
            this.commandline := StrReplace(cm,this.exe)
            while !(this.findAndKill() = ""){
                sleep 10
            }
            sleep 500
            this.flushWebData()
            Run, % cm, ,Min , OutputVarPid
            this.pid := OutputVarPid
            while !(WinExist("ahk_pid " OutputVarPid))
							sleep 10
            ;this.hwnd := WinExist("ahk_pid " OutputVarPid)
            l := this.getPageList()
            if (l = "") || (l.MaxIndex() = "0"){
                Msgbox,262144,, % "FET ERROR 1"
                exitapp
            }
            this.pageID := ""
            this.pageData := ""
            for k,v in l
            {
                ;msgbox % 
                if (instr(v.url,this.url)) || (v.url = this.url){
                    this.pageID := v.id
                    this.pageData := v
                    break
                }
            }
            if (this.pageID = ""){
                Msgbox,262144,, % "FET ERROR 2"
                exitapp
            }
            if (this._console){
                this.createConsoleGui()
                this.showConsole()
                this.console.log("ready")
            }
            this.connectWS(this.pageID)
            this.windowProps := this.findWindow()
            ;Array_Gui(this.windowprops)
        }
        findAndKill()
        {
                windows := {}
                 for Item in ComObjGet("winmgmts:").ExecQuery("SELECT CommandLine,Handle,ExecutablePath,ProcessId FROM Win32_Process" . " WHERE Name = '" this.exe "'"){
                    if (instr(item.CommandLine,this.datadir)){
                        vtrwin := {"commandline":item.CommandLine
                        ,"handle":item.handle
                        ,"ProcessId":item.ProcessId}
                        windows.push(vtrwin)
                    }    
                }
                for k,v in windows
                {
                    hWnd := winExist("ahk_pid "  v.handle)
                    WinKill, % "ahk_id" hwnd
                    WinWaitClose % "ahk_id" hwnd
                }
                windows := {}
                 for Item in ComObjGet("winmgmts:").ExecQuery("SELECT CommandLine,Handle,ExecutablePath,ProcessId FROM Win32_Process" . " WHERE Name = '" this.exe "'"){
                    if (instr(item.CommandLine,this.datadir)){
                        vtrwin := {"commandline":item.CommandLine
                        ,"handle":item.handle
                        ,"ProcessId":item.ProcessId}
                        windows.push(vtrwin)
                    }    
                }                
                return windows.maxIndex()        
        }
        __Delete()
        {
            ;msgbox % A_ThisFunc
            this.Disconnect(A_thisFunc)
            this.console.__Delete() 
        }
        kill()
        {
           
                    
                    closed := false
                    while !(closed){
                        Winclose, % "ahk_id" . this.hwnd
                        WinWaitClose, % "ahk_id" . this.hwnd, , 2 
                        if (errorlevel){
                            winKill, % "ahk_id" this.hwnd
                            WinWaitClose, % "ahk_id" . this.hwnd, , 2 
                        }
                        closed := true    
                        if (A_index >= 3){
                            Throw Exception( "`n" A_ThisFunc "`nTimeout")
                        }
                    }
                    return closed
                
        }
        findWindow()
        {

                hits := 0
           
                for Item in ComObjGet("winmgmts:").ExecQuery("SELECT CommandLine,Handle,ExecutablePath,ProcessId FROM Win32_Process" . " WHERE Name = '" this.exe "'"){
                    if (instr(item.CommandLine,this.commandLine)){
                        win := {"commandline":item.CommandLine
                     ,"handle":item.handle
                        ,"ProcessId":item.ProcessId}
                        hits++
                    }    
                 }
                if !(IsObject(win)){
                    return false
                }
               
                windows := {}
                WinGet, id, list,,, Program Manager
                Loop, %id%
                {
                    this_id := id%A_Index%
                    ;WinActivate, ahk_id %this_id%
                    WinGetClass, this_class, ahk_id %this_id%
                    WinGetTitle, this_title, ahk_id %this_id%
                    WinGet, this_hwnd, id, ahk_id %this_id%
                    WinGet, this_pid, pid, ahk_id %this_id%
                    
                    if (instr(this_class,"Chrome_WidgetWin_1")){
                        t := {"pid":this_pid,"hwnd":this_hwnd,"title":this_title,"class":this_class}
                        windows.push(t)
                    }

                } 
                for k,v in windows
                    {
                        if (v.pid = win.ProcessId) || (v.pid = win.handle){
                            for x,y in v
                                win[x] := y 

                        }
                    }
                    if !(win.HasKey("pid")){
                        return false
                    }
                return win  



          
        }
        windowData {
            get {
                    window := this.findWindow()
                    ;window := this.windowProps
                    return window
            }
        }
        hwnd {
            get {
                return this.windowProps.hwnd
            }
        }
        title {
            get {
                WinGetTitle, OutputVar , % "ahk_id " this.hwnd
                return OutputVar
            }
        }
        pos {
            get {
                pos := {}
                WinGetPos, X, Y, Width, Height, % "ahk_id " this.hwnd, , ,
                pos.x := x , pos.y := y, pos.w := width , pos.h := Height
                return pos
            }
        }
        moveDown(pixels := 1)
        {
            p := this.pos
            WinMove, % "ahk_id " this.hwnd,, % p.X, % (p.Y + pixels)
        }
        moveUp(pixels := 1)
        {
            p := this.pos
            WinMove, % "ahk_id " this.hwnd,, % p.X, % (p.Y - pixels)
        }
        moveLeft(pixels := 1)
        {
            p := this.pos
            WinMove, % "ahk_id " this.hwnd,, % (p.X - pixels), % p.Y 
        }
        moveRight(pixels := 1)
        {
            p := this.pos
            WinMove, % "ahk_id " this.hwnd,, % (p.X + pixels), % p.Y 
        }
        hide()
        {
            WinHide, % "ahk_id " this.hwnd
        }
        move(X := "0", Y := "0",W := "", H := "")
        {
            WinMove, % "ahk_id " this.hwnd,, % X, % Y, % w, % h
        }
        activate()
        {
            WinActivate, % "ahk_id " this.hwnd
            WinWaitActive, % "ahk_id " this.hwnd,,0
            if errorLevel
                return false
            return true
            
        }
        show()
        {
            WinShow, % "ahk_id " this.hwnd
        }
        checkConnection()
        {
            Res := this.Call("Browser.getVersion")
        }
        Disconnect(reason:="")
        {
            this.ws.OnClose()
            if this.ws.connected
            {
                this.console.log("The connection couldn't be closed. The connection is already closed!","text-danger")
                this.connected := false
                this.ws := ""
                return
            }
            this.connected := false
            this.console.log("The connection has been closed!" "<br>Reason: " reason ,"text-danger")
            this.ws := ""
            this.kill()
            ;this.findAndKill()
        }
        connectWS(pageID)
        {
            this.connected := false
            this.console.flush()
            this.console.loading
            wsUri := "/devtools/page/" pageID
            port := this.debugPort
            ;callback := 
            try {
                this.ws := new WSSession("localhost", port,wsUri)
            }
            catch e {
                ;Array_Gui(e)
                    this.console.flush()
                    this.console.log("File: " e.file "<br>Line: " e.line "<br>What: " e.what "<br>Message: " e.Message,"text-danger")
                    this.console.pageSelect()
                    this.ws := ""
                    return
            }
            
            
            this.ws.On(WSOpcodes.Text,ObjBindMethod(this,"callback"))
            this.ws.On(WSOpcodes.Close,ObjBindMethod(this,"Disconnect"))
            e := 0
            while this.ws.connected
            {   
                sleep 10
                ;tooltip % e
                if (e >= 2000){
                    this.console.flush()
                    this.console.log("error connecting","text-danger")
                    this.console.pageSelect()
                    this.ws := ""
                    return
                }
                e++ 
            }
                ;e++
            this.connected := true
            this.console.flush()
            this.console.puppCommands()
            this.console.log("connected to " wsUri,"text-success")
            this.EnableDomains()
            this.Call("Page.bringToFront","",false)
            ;this.Call("Fetch.enable",{"patterns":[{"requestStage":"Response"}]})
            ;KeepAlive := ObjBindMethod(this,"keepAlive")
			;SetTimer, % keepAlive, -15000

        }
        WaitForLoad(DesiredState:="complete", Interval:=100)
		{
           ; if (this.ws.connected) || !(this.ws.connected){
           ;     this.console.log("error ej connected")
           ;     return 
           ; }

			while (this.Evaluate("document.readyState").value != DesiredState){
                if !(this.connected)
                    return 
                Sleep, Interval
                if (A_Index >= 15){
                    Throw Exception( "`n" A_ThisFunc "`nTimeout")
                }
            }
				
		}
       
        createConsoleGui()
        {
            if !(isObject(this.console))
            this.console := new puppeteerConsole(this)
        }
        showConsole()
        {
            this.console.show()
        }
        goto(_url := "about:blank")
        {
            ;ToolTip, % A_ThisFunc
            ;if !(Trim(_url) = "")
            ;    return
            p := {"url":_url}
            this.Call("Page.navigate", p,true)
            this.WaitForLoad(DesiredState:="complete", Interval:=100)
            this.Call("Page.bringToFront")
            
        }


        getPageList()
        {
            
            /*
            req := ComObjCreate("MSXML2.XMLHTTP.6.0")
            _url := "http://127.0.0.1:" this.debugPort "/json"
            req.open("GET",_url,true)
            req.setRequestHeader("Cache-Control","no-cache,no-store")
            req.send()
        
            e := 0
            while (req.readyState != 4){
                e++
            }
            */
            try {
                _url := "http://127.0.0.1:" this.debugPort "/json"
            	req := ComObjCreate("WinHttp.WinHttpRequest.5.1")
                req.open("GET", _url,true)
                req.send()
                req.WaitForResponse()
                r := req.responseText      
                req := ""
            try {
                return JSON.LOAD(r)
            }   catch e {
                return r
            }   
            } catch e {
                return ""
            }

             


        }
        createInstance()
        {
            
        }
        flushWebData()
        {
            datadir := this.dataDir
            files := {}
            Loop, Files, %  datadir "\default\*.*" ,
                files[A_LoopFileFullPath] := ""
            for k,v in files    
                if (instr(k,"Web Data")){
                     FileDelete, % k
                     if errorlevel
                        return ;msgbox % "WTF " A_ThisFunc
                }
                   

        }

        chromiumPaths()
        {
                
			chromiumPaths := {}
			ChromePath := ComObjGet("winmgmts:").ExecQuery("Select * from Win32_ShortcutFile where Name=""" StrReplace(A_StartMenuCommon "\Programs\Google Chrome.lnk", "\", "\\") """").ItemIndex(0).Target
			if (ChromePath == "")
				RegRead, ChromePath, HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe
			EdgePath := ComObjGet("winmgmts:").ExecQuery("Select * from Win32_ShortcutFile where Name=""" StrReplace(A_StartMenuCommon "\Programs\Microsoft Edge.lnk", "\", "\\") """").ItemIndex(0).Target
			if (EdgePath == "")
				RegRead, EdgePath, HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe
			BravePath := ComObjGet("winmgmts:").ExecQuery("Select * from Win32_ShortcutFile where Name=""" StrReplace(A_StartMenuCommon "\Programs\Brave.lnk", "\", "\\") """").ItemIndex(0).Target
			if (BravePath == "")
				RegRead, BravePath, HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\brave.exe
			chromiumPaths["brave.exe"] 	:= 	this.CliEscape(BravePath)
			chromiumPaths["msedge.exe"] :=  this.CliEscape(EdgePath)
			chromiumPaths["chrome.exe"] :=  this.CliEscape(ChromePath)
			
            return chromiumPaths

        }
        CliEscape(Param)
        {
            return """" RegExReplace(Param, "(\\*)""", "$1$1\""") """"
        }
        EnableDomains()
        {
            if !(this.connected){
                this.console.log("error ej connected")
                return   
           }
            /*
            Console			https://chromedevtools.github.io/devtools-protocol/tot/Console/
            Debugger		https://chromedevtools.github.io/devtools-protocol/tot/Debugger/
            DOM				https://chromedevtools.github.io/devtools-protocol/tot/DOM/
            DOMDebugger		https://chromedevtools.github.io/devtools-protocol/tot/DOMDebugger/
            Page			https://chromedevtools.github.io/devtools-protocol/tot/Page/
            Network			https://chromedevtools.github.io/devtools-protocol/tot/Network/
            Runtime			https://chromedevtools.github.io/devtools-protocol/tot/Runtime/
            Security		https://chromedevtools.github.io/devtools-protocol/tot/Security/
            CSS				https://chromedevtools.github.io/devtools-protocol/tot/CSS/
            Accessibility 	https://chromedevtools.github.io/devtools-protocol/tot/Accessibility/
            Animation 		https://chromedevtools.github.io/devtools-protocol/tot/Animation/

            */
            Wait := {"Console":false,"Page":true,"Dom":true,"Network":true,"CSS":false,"DOMStorage":true,"Runtime":false}
            domains := this.domains
            r := ""
            For i in domains
                {
                    this.Call(Trim(domains[i] . ".enable"),"",((wait.HasKey(domains[i]) && wait[domains[i]]) ? true : false))
                    
                    sleep 100
                    this.console.log(domains[i] " enabled","text-primary") 
                }   
                
            

        }
		Evaluate(JS)
		{
            if !(this.connected){
                this.console.log("error ej connected")
                return   
           }
			response := this.Call("Runtime.evaluate",
			( LTrim Join
			{
				"expression": JS,
				"objectGroup": "console",
				"includeCommandLineAPI": true,
				"silent": false,
				"returnByValue": true,
				"userGesture": true,
				"awaitPromise": true
			}
			))
			;await promise funkar som false
			if (response.exceptionDetails){
                if (this._console){
				this.console.log(JSON.DUMP({"Code": JS, "exceptionDetails": response.exceptionDetails}),"text-danger")
                } else {
                    throw Exception(response.result.description, -1
					, Jxon_Dump({"Code": JS
					, "exceptionDetails": response.exceptionDetails}))
                }

            }

			
			return response.result
		}
        fixPayload(payload)
        {
            q = "id":true,
            qt = "id":1,
            payload := StrReplace(payload,":0,",":false,")
            payload := StrReplace(payload,":1,",":true,")
            payload := StrReplace(payload,":1}",":true}")
            payload := StrReplace(payload,":0}",":false}")
            payload := StrReplace(payload,q,qt)
            return payload
        }
        awaitResponse(_ID)
        {
            e := 0
            while !(this.responses[_ID]){
                if !(this.connected)
                {
                    
                    
                    response := {"result" : { "value" : "error : no connection"},"id" :_ID,"error":true}
                    this.responses[_ID] := response
                    response := this.responses.Delete(_ID)
                    return response 
                }
                e++
                sleep 10
                if (e >= 1000){
                    ;this.responses[_ID] := true
                    response := {"result" : { "value" : "error : timeout"},"id" :_ID,"error":{"timeout": e},"exceptionDetails": "timeout"}
                    this.responses[_ID] := response
                    response := this.responses.Delete(_ID)
                   
                    ;msgbox % "error"
                    return response
                }
            }
            response := this.responses.Delete(_ID)
            return response
        }
        Call(DomainMethod,params := "",WaitForResponse:=true)
        {
            ;if (this.ws.connected) || !(this.ws.connected){
            ;    this.console.log("error ej connected")
            ;    return 
           ; }
           if !(this.connected){
                this.console.log("error ej connected")
                return   
           }
            _ID := this._ID += 1
            params := (params = "" ? {} : params)
            ;p := Jxon_Dump(params)
            ;msg := {"id":_ID,"method":DomainMethod,"params": params}

			O := Jxon_Dump({"id": _ID
			, "params": Params ? Params : {}
			, "method": DomainMethod})
            O := this.fixPayload(O)
            if (WaitForResponse)
            this.responses[_ID] := False
            this.ws.SendText(O)
            this.console.logSend("wait: " WaitForResponse "<br>" o ,"text-primary")
            if !WaitForResponse
            return _ID
            ;this.responses[_ID] := False
            response := this.awaitResponse(_ID)

			
			if (response.error){
                this.console.log(json.dump(response),"text-danger")
            }
				;throw Exception("Chrome indicated error in response",, Jxon_Dump(response.error))
			
			return response.result
        }
        callback(Event)
        {
            
            Response := Event.Data
            ;FileAppend % "`n`n-----------------------------------`n" JSON.DUMP(response), % A_ScriptDir "\log.txt" 
            this.messages.push(event)
            ;this.Call("Fetch.enable",{"patterns":[{"requestStage":"Response"}]})
            this.messages.push(response)
            try {
                Response.JSON := Jxon_Load(Response.payloadtext)
            } catch e {
                jj := StrSplit(Response.payloadtext,"}{")
                ;Array_Gui(j)
                j := jj[jj.MaxIndex()]
                if (subStr(j,1,1) = "{") {
                    j .= j "}"
                } else {
                    j := "{" j
                }
                Try {
                    Response.JSON := JSON.LOAD(j)
                    ;msgbox % j
                }
                catch e {
                    this.console.log(JSON.DUMP(JJ),"text-danger")
                    return
                }
                
            }
            
            if (response.json.HasKey("ID")){
                if (this.responses.HasKey(response.json.id)){
                this.responses[response.json.id] := Response.JSON
                this.console.log(JSON.DUMP(Response.JSON),"text-success")
                return
                }

            }
            if (response.json.HasKey("method")) && (response.json.method = "Inspector.detached"){
                this.Disconnect(response.json.method)
                return
            }
            this.console.log(Response.payloadtext, "text-warning")
            event := ""
            response := ""
            return 
            
            
        }
        methods {
            get {
                Wait := {"Console":false,"Page":true,"Dom":true,"Network":true,"CSS":false,"DOMStorage":true}
          
                o :=    {"DOM.enable":true
                        ,"Console.enable":False
                        ,"Page.enable":True
                        ,"Network.enable":True
                        ,"Browser.getVersion":true
                        ,"DOM.getDocument":true
                        ,"Page.bringToFront":false
                        ,"Page.captureScreenshot":true
                        ,"Page.navigate":true}
                return o
            }
        }
}


