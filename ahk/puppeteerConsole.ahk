
class puppeteerConsole
    {
        __new(main)
        {
            this.main := main
            _url := A_ScriptDir "\web\gc-tmp.html"
            if !(fileExist(_url)){
                _url := StrReplace(A_scriptdir, "\ahk","\web\gc-tmp.html")
            }
            _url := StrReplace(_url,"\","/")
            _url := StrReplace(_url,A_Space,"%20")
            _url := "file:///" _url
            Static rrWb
            Gui New, +LastFound +Resize +HwndGhwnd -DPIScale 
            Gui Margin, 0, 0
            Gui ,  Add, ActiveX, w800 h600 vrrWB hwndwbHwnd, Shell.Explorer
            this.controls.AcX := wbHwnd	
           

            
            rrWB.navigate(_url)
            
            While	(rrWB.readyState != 4 || rrWB.document.readyState != "complete" || rrWB.busy){
                sleep 10
            } 
                    Sleep 10
                    
            


            this.ViewUrl := _url2
            this.wb  := rrWB
            this.doc := this.wb.document
            this.hwnd := Ghwnd
            this.wbHwnd := wbHwnd

                
            ComObjConnect(this.doc,this)

            
            
            OnMessage(0x100,ObjBindMethod(this, "gui_KeyDown")) ; WM_KEYDOWN
            OnMessage(0x101,ObjBindMethod(this, "gui_KeyDown"))
            OnMessage(0x05,ObjBindMethod(this, "guiSize"))	; WM_CLOSE
            OnMessage(WM_SYSCOMMAND:=0x112,ObjBindMethod(this, "guiKill"))       
            this.start
                 
        }
        __delete()
        {
            hwnd := this.hwnd
            Gui, % this.hWnd ":Destroy"
            this := ""
        }

        guiKill(wParam, lParam, nMsg, hwnd)
        {

            ;this.main.ws := ""
            ;exitapp
            static SC_CLOSE := 0xF060
            if (wParam = SC_CLOSE && this.hwnd = WinExist("A")) {
                MsgBox 4,, Är du säker att du vill stänga?
                IfMsgBox No
                    return 0  
                ExitApp	
            }

        }
        loading {
            get {
                this.doc.getElementById("console").innerHTML := "connectar..<div class='spinner-border text-primary'></div>"
            }
        }
        sendJs()
        {
            js := this.doc.getElementById("pupp-js").value
            ;MsgBox, % js
            js := trim(js)
            this.doc.getElementById("pupp-js").value := this.main.Evaluate(js).value
            return
        }
        log(text,_class := "text-dark")
        {
            
                text := "<span class='" _class "'>" text "</span>"
           
                
            text :=  text "<br>-----------------------------------<br>"  


            if (_class = "text-danger"){
                
                html := this.doc.getElementById("consoleError").innerhtml 
                html := text "<br>" html
                this.doc.getElementById("consoleError").innerhtml := html
                return
               
            }

            html := this.doc.getElementById("console").innerhtml 
            html := text "<br>" html

            html := (StrLen(html) > 100000 ? text "<br>" : html)
            ;html := 
            this.doc.getElementById("console").innerhtml := html
            this.doc.getElementById("recivedLen").innerText := StrLen(html)
        }
        logSend(text,_class := "text-dark") 
        {
            text := "<span class='" _class "'>" text "</span>"
            text :=  text "<br>-----------------------------------<br>"  
            html := this.doc.getElementById("sends").innerhtml 
            html := text "<br>" html
            html := (StrLen(html) > 100000 ? text "<br>" : html)
            ;html := 
            this.doc.getElementById("sends").innerhtml := html
            this.doc.getElementById("sentLen").innerText := StrLen(html)
        }        
        show()
        {
            hwnd := this.hwnd
	        Gui , %hwnd%: show,   AutoSize , % this.main.pageID "`t" this.main.datadir
        }
        	
        guiSize(wParam, lParam, nMsg, hwnd)
        {

            if this.hwnd  != hwnd
                return
            if wParam
                return 
            w := lParam & 0xFFFF
            h := lParam >> 16
            
            GuiControl, Move, % this.wbHwnd , %  "w" w "h" h



        }
        flush()
        {
            this.doc.getElementById("console").innerhtml := ""
            this.doc.getElementById("sends").innerhtml := ""
        }		
        gui_KeyDown(wParam, lParam, nMsg, hwnd) 
        {

                ;if this.hwnd  != hwnd
            ;	return
                if this.hwnd != WinExist("A")
                    return 
                ;tooltip % this.hwnd "`t" hwnd "`t"	this.wbhwnd

                wb := this.wb
                pipa := ComObjQuery(wb, "{00000117-0000-0000-C000-000000000046}")
                VarSetCapacity(kMsg, 48), NumPut(A_GuiY, NumPut(A_GuiX
                , NumPut(A_EventInfo, NumPut(lParam, NumPut(wParam
                , NumPut(nMsg, NumPut(hwnd, kMsg)))), "uint"), "int"), "int")
                Loop 2
                r := DllCall(NumGet(NumGet(1*pipa)+5*A_PtrSize), "ptr", pipa, "ptr", &kMsg)

                until wParam != 9 || wb.Document.activeElement != ""
                ObjRelease(pipa)
                if r = 0 
                    return 0
        } 
        onclick()
        {

            

            doc := this.doc
            elid := doc.parentWindow.event.srcElement.id
            tagname := doc.parentWindow.event.srcElement.tagName
            ClassName := doc.parentWindow.event.srcElement.className
            innerText := doc.parentWindow.event.srcElement.innerText
            if (instr(elid,"gc-copy-")){
                Clipboard := StrReplace(elid,"gc-copy-")
                ToolTip,  % "Kopierat " Clipboard
                sleep 1000
                ToolTip,
                return
            }
            if (elid = "puppConnect"){
                ;this.puppConnect()
                this.main.connectWS(this.main.pageID)
                return
            }
            if (elid ="puppCommandSend"){
                this.puppSendCommand()
            }
            if (elid ="pupp-diss"){
                this.main.Disconnect()
                return
            }
            if (elid = "pupp_js_send"){
                this.sendJS()
                return
            }
            if (elid = "pupp-update"){
                this.start
                return
            }
            if (elid ="pupp-flush"){
                this.flush()
                return
            }
            if (elid = "puppLaunch"){
                this.main.launch()
                return
            }
            ;if (elid = "puppLaunch"){
            ;    this.main.runChrome(ProfilePath := A_Scriptdir "\crm\test",URLString := "https://google.se")
            ;    this.start
            ;    return
            ;}
            ;if (instr(elid,"{{gc-copy-")){
            ;        this.copydata(elid)
            ;        return
            ;}
            



        }
        start {
            get {
                html = 
                (LTRIM JOIN
                <div class="row">
                <div class="col mb-3">
                 <div class="card" id=""> <!-- Card -->
                
                
                
                <div  class="card-body" > <!-- Cardbody -->
                <h4  class="card-title border-bottom mb-3">Recived<span class="ml-2 badge badge-secondary" id="recivedLen"></span></h4>
                <div id="console"  class="overflow-auto" style="max-height: 400px;" id=""></div>
                </div> <!--Card Body end -->
                </div> <!-- card end -->
                </div>
                <div class="col mb-3">
                <div class="card" id=""> <!-- Card -->
                
                
                
                <div  class="card-body" id=""> <!-- Cardbody -->
                <h4 class="card-title border-bottom mb-3">Commands</h4>
                <div class="mb-3">
                <button class="btn btn-outline-info mr-2 mb-2" id="puppLaunch">Launch</button>
                <button class="btn btn-outline-primary mr-2 mb-2" id="puppConnect">connect</button>
                <button class="btn btn-outline-danger mr-2 mb-2" id="pupp-diss">disconnect</button>
                <button class="btn btn-outline-warning mr-2 mb-2" id="pupp-update">update</button>
                <button class="btn btn-outline-secondary mr-2 mb-2" id="pupp-flush">rensa</button>
                </div>

                <div id="puppSelect"></div>
                <div id="pupp-command"></div>
                <div class="input-group mb-3">
                <div class="input-group-prepend">
                    <span class="input-group-text">JavaScript</span>
                </div>
                <textarea class="form-control" id="pupp-js" rows="10"></textarea>
                </div>
                <button id="pupp_js_send" class="btn btn-outline-primary">send js </button>
                </div> <!--Card Body end -->
                </div> <!-- card end -->

                </div>
                </div>
                <div class="row">
                <div class="col mb-3">
                <div class="card" id=""> <!-- Card -->
                
                
                
                <div  class="card-body"  id=""> <!-- Cardbody -->
                <h4  class="card-title border-bottom mb-3">sent<span class="ml-2 badge badge-secondary" id="sentLen"></span></h4>
                <div id="sends" class="overflow-auto" style="max-height: 400px;"></div>
                </div> <!--Card Body end -->
                </div> <!-- card end -->
                </div>
                <div class="col mb-3">
                                <div class="card" id=""> <!-- Card -->
                
                
                
                <div  class="card-body" > <!-- Cardbody -->
                <h4  class="card-title border-bottom mb-3">jserror<span class="ml-2 badge badge-secondary" id="jserror"></span></h4>
                <div id="consoleError"  class="overflow-auto" style="max-height: 400px;" id=""></div>
                </div> <!--Card Body end -->
                </div> <!-- card end -->
                </div>
                </div>
                )
                 this.doc.getElementById("mainTag").innerHTML := html
                 ;this.pageSelect()
                 ;this.pageSelect()
            }
        }
        pageSelect()
        {
            this.doc.getElementById("puppSelect").innerHTML := ""
            html = 
            (LTRIM JOIN
            <div class="input-group mb-2 input-group-sm has-validation">      
                        <div class="input-group-prepend">
                                <span class="input-group-text">Page</span>
                        </div>  
                                <select class="custom-select custom-select-sm" onchange="" id="puppeteerPages" >
                                        <option value="0">Välj..</option>

                                        {{options}}
                                        </select>
                        <div class="input-group-append"><button class="btn btn-outline-primary" id="puppConnect">connect</button><button class="btn btn-outline-danger" id="pupp-diss">diss</button><button class="btn btn-outline-warning" id="pupp-update">upd</button></div>
            </div>
            )
            plist := this.main.getPageList()
            
            for k,v in plist
                options .= "<option value='" v.id "'>" v.id " | " v.url "</option>"
            ;Array_Gui(plist)
            html := StrReplace(html,"{{options}}",options)
            this.doc.getElementById("puppSelect").innerHTML := html

        }
        puppConnect()
        {
            id := this.doc.getElementById("puppeteerPages").value 
            if (Strlen(id) < 5){
                msgbox % "error"
                return
            }
            this.main.connectWS(id)
            this.puppCommands()
        }
        puppCommands()
        {
            html = 
            (LTRIM JOIN
            <div class="input-group mb-2 input-group-sm has-validation">      
                        <div class="input-group-prepend">
                                <span class="input-group-text">Command</span>
                        </div>  
                                <select class="custom-select custom-select-sm" onchange="" id="puppeteerCommands" >
                                        <option value="0">Välj..</option>

                                        <option value="Browser.getVersion|1">Browser.getVersion</option>
                                        <option value="Page.reload|1">Page.reload</option>
                                        <option value="DOM.getDocument|1">DOM.getDocument</option>
                                        <option value="Target.getTargets|1">Target.getTargets</option>
                                        {{options}}
                                        </select>
                        <div class="input-group-append"><button class="btn btn-outline-primary" id="puppCommandSend">Send</button></div>
            </div>
            )
            dom := ["Console","DOMStorage","Debugger","DOM","DOMDebugger","Page","Network","CSS","Overlay","Runtime"]
             op := ""
             for k,v in dom
             op .= "<option value='" v ".enable'>" v ".enable</option>"
             html := StrReplace(html,"{{options}}",op)
             this.doc.getElementById("pupp-command").innerHTML := html
        }
        puppSendCommand()
        {
            val := this.doc.getElementById("puppeteerCommands").value
            if (val = "0"){
                return
            }
            val := StrSplit(val,"|")
            DomainMethod := val[1]
            wait := (val[2] = 1 ? true : false)
            
            
            r := this.main.call(DomainMethod,"",wait)
            ;msgbox % Jxon_Dump(r)
        }

    }