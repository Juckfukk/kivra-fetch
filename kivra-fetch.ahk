DetectHiddenWindows, on
#NoEnv  
#MaxMem 1000
SendMode Input  
SetWorkingDir %A_ScriptDir%  
SetMouseDelay -1
SetControlDelay -1
SetBatchLines -1
#include %A_ScriptDir%\ahk\arrayGui.ahk
#include %A_ScriptDir%\ahk\json.ahk




kiv := new kivraFetch()

return


class kivraFetch
    {
        static saved_receipts_root_path := A_AppData "\kivra-fetch"
        static saved_receipts_path := A_AppData "\kivra-fetch\receipts"
        static kivra_fetch_ico_path :=  A_ScriptDir "\assets\kivra-logo.ico"
        __new()
        {

            _url := A_ScriptDir "\web\index.html"
            if !(fileExist(_url)){
                _url := StrReplace(A_scriptdir, "\ahk","\web\index.html")
            }
            _url := StrReplace(_url,"\","/")
            _url := StrReplace(_url,A_Space,"%20")
            _url := "file:///" _url
            Static rrWb
            Gui New, +LastFound +Resize +HwndGhwnd -DPIScale 
            Gui Margin, 0, 0
            Gui ,  Add, ActiveX, w1000 h900 vrrWB hwndwbHwnd, Shell.Explorer
           
            
            rrWB.navigate(_url)
            
            While	(rrWB.readyState != 4 || rrWB.document.readyState != "complete" || rrWB.busy){
                sleep 10
            } 
                    Sleep 10
                                

            this.wb  := rrWB
            this.doc := this.wb.document
            this.hwnd := Ghwnd
            this.wbHwnd := wbHwnd

                
            ComObjConnect(this.doc,this)
            OnMessage(0x100,ObjBindMethod(this, "gui_KeyDown")) ; WM_KEYDOWN
            OnMessage(0x101,ObjBindMethod(this, "gui_KeyDown"))
            OnMessage(0x05,ObjBindMethod(this, "guiSize"))	; WM_CLOSE
            OnMessage(WM_SYSCOMMAND:=0x112,ObjBindMethod(this, "guiKill"))    
            OnExit(ObjBindMethod(this, "exiting"))

            this.loadIcon()
            this.show()
            this.start   
            this.loadsavedReceipts()
            

        }
        loadIcon()
        {
            
            if (fileExist(this.kivra_fetch_ico_path)){
            Menu, Tray, Icon, % this.kivra_fetch_ico_path
            hIcon := DllCall( "LoadImage", UInt,0, Str,this.kivra_fetch_ico_path , UInt,1, UInt,0, UInt,0, UInt,0x10 )
            SendMessage, 0x80, 0, % hIcon ,, % "ahk_id"  this.hwnd ; One affects Title bar and
            SendMessage, 0x80, 1, % hIcon ,, % "ahk_id"  this.hwnd ; the other the ALT+TAB menu
            }

        }
        exiting()
        {
            this.saveReceiptsIndex()
        }
        saveReceiptsIndex()
        {
            if (fileExist(this.saved_receipts_root_path "\index.json")){
                FileDelete,  % this.saved_receipts_root_path "\index.json"
            }
            FileAppend, % JSON.DUMP(this.receipts), % this.saved_receipts_root_path "\index.json"
        }
        loadsavedReceipts()
        {
            if !(fileExist(this.saved_receipts_root_path) = "D"){
                FileCreateDir, % this.saved_receipts_root_path
            }
            if !(fileExist(this.saved_receipts_path) = "D"){
                FileCreateDir, % this.saved_receipts_path
            }
            this.savedReceipts := {}
            Loop, Files, % this.saved_receipts_path "\*.json"
            {
                this.savedReceipts[StrReplace(A_loopFileName,"." A_LoopFileExt)] := A_LoopFileFullPath
            }
            if (fileExist(this.saved_receipts_root_path "\index.json")){
                FileRead,index, % this.saved_receipts_root_path "\index.json"
                this.receipts := JSON.LOAD(index)
               
                for k,v in this.receipts.list
                    v.__saved := this.savedReceipts.hasKey(v.key)

                this.receiptsList()
            }
            if !(IsObject(this.receipts.list)) || (this.receipts.list.count() = 0){
                this.doc.getElementById("receiptsList").innerHTML := ""
                this.showError("Börja med att logga in med knappen nedan.","primary")
            }
        }
        show()
        {
	        Gui,% this.hwnd ":Show",   AutoSize , % "kivra-fetch"
        }
        __delete()
        {
            
            Gui, % this.hWnd ":Destroy"
            this := ""
        }
        guiKill(wParam, lParam, nMsg, hwnd)
        {
            static SC_CLOSE := 0xF060
            if (wParam = SC_CLOSE && this.hwnd = WinExist("A")) {
                MsgBox 4,, Är du säker att du vill stänga?
                IfMsgBox No
                    return 0  
                ExitApp	
            }

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
        gui_KeyDown(wParam, lParam, nMsg, hwnd) 
        {


                if this.hwnd != WinExist("A")
                    return 
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

            src := this.doc.parentWindow.event.srcElement
            if (src.disabled)
                return
            if (src.id = "")
                return
            if (src.id ="kivra-fetch-table-scrolltop"){
                this.scrollToTop(src)
                return 
            }
            if (src.id = "kivra-fetch-show-more"){
                this.showMore(src)
                return
            }
            if (src.id = "kivra-fetch-showReceiptsFolder"){
                this.showReceiptsFolder()
                return
            }
            if (src.id = "kivra-fetch-getSession"){
                this.getSession()
                return
            }
            if (src.id = "kivra-fetch-spara-alla"){
                this.saveAll()
                return
            }
            if (instr(src.id,"kivra-fetch-save-")){
                this.saveReceipt(src.id)
                return
            }
            if (instr(src.id,"kivra-fetch-show-")){
                this.showReceipt(src.id)
                return
            }
            if (instr(src.id,"kivra-fetch-delete-")){
                this.deleteReceipt(src.id)
                return
            }
        }
        onkeyup()
        {
            src := this.doc.parentWindow.event.srcElement

        }
        saveReceipt(id,_reload := true)
        {
            if !(this.isInloggad){
                msg := "Sessionen har gått ut, logga in igen."
                this.ShowError(msg)
                return {"error":msg}
            }

            key := StrReplace(id,"kivra-fetch-save-")
            ih := this.doc.getElementById("kivra-fetch-save-" key).innerHTML
            this.doc.getElementById("kivra-fetch-save-" key).innerHTML := "<div class='spinner-border spinner-border-sm' role='status'></div>"
            r := this.getReceipt(key)
            if (r.HasKey("error")){
                this.ShowError(r.error)
                return r.error
            }
            FileAppend, % JSON.DUMP(r), % this.saved_receipts_path "\" key ".json"
            this.doc.getElementById("kivra-fetch-save-" key).innerHTML := "0"
            this.doc.getElementById("kivra-fetch-save-" key).hidden := true
            this.doc.getElementById("kivra-fetch-saved-" key).innerHTML := "<i class='bi bi-file-earmark-check text-success'></i>"
            if (_reload){
                this.loadsavedReceipts()
                this.receiptsList()
            }

        }
        showError(msg,type := "danger")
        {
            html = 
            (LTRIM Join
            <div class="alert alert-%type% alert-dismissible fade show" role="alert">
            %msg%
            <button type="button" class="close" data-dismiss="alert" aria-label="Close">
                <span aria-hidden="true">&times;</span>
            </button>
            </div>
            )
            this.doc.getElementById("error").innerHTML := html
        }
        saveAll()
        {
            if !(this.isInloggad){
                msg := "Sessionen har gått ut, logga in igen."
                this.ShowError(msg)
                return {"error":msg}
            }
            totalUnsaved := 0
            saved := 0
            for k,v in this.receipts.list
            {
                if !(v.__saved)
                    totalUnsaved++
            }

            for k,v in this.receipts.list
            {
                if !(v.__saved){
                    r := this.saveReceipt(v.key,false)
                    if (r.HasKey("error")){
                            this.ShowError(r.error)
                            return r.error   
                    }
                    saved++
                    sleep 75
                    Tooltip % saved " av " totalUnsaved
                }
            }
            Tooltip,
            this.loadsavedReceipts()
            this.receiptsList()  
        }
        start {
            get {
                html = 
                (LTRIM JOIN
                <div class="row">
                    <div class="col mb-3">
                        <div class="card">
                            <div class="card-body">
                                <div class="row">
                                <div class="col mb-3" id="error">
                                </div>
                                </div>
                                <div class="row">
                                

                                    <div class="col mb-3" id="actions">

                                    <div class="input-group mb-3">
                                    <div class="input-group-prepend">
                                        <label class="input-group-text" for="PreferredBrowser">Browser</label>
                                    </div>
                                    <select class="custom-select" id="PreferredBrowser">
                                        <option value="chrome.exe">Chrome</option>
                                        <option value="msedge.exe">Edge</option>
                                        <option value="brave.exe">Brave</option>
                                    </select>
                                    <div class="input-group-append">
                                    <button class="btn btn-outline-primary" id="kivra-fetch-getSession">Logga in</button>
                                    </div>
                                    </div>





                                    
                                    <button class="btn btn-outline-success mb-3 mr-2" id="kivra-fetch-showReceiptsFolder">Visa mapp</button>
                                    </div>

                                    <div class="col mb-3" id="sessionInfo">
                                    
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="row">
                <div class="col mb-3" id="receiptsList">
                <div class="card">
                <div class="card-body">
                <div class='spinner-border text-primary'></div>
                </div>
                </div>
                </div>
                </div>
                )
                this.doc.getElementById("currentView").innerHTML := html
            }
        }
        showReceiptsFolder()
        {
            Run % this.saved_receipts_path
            return
        }
        isInloggad {
            get {
                if !(IsObject(this.session)){
                    return false
                }
                if !(this.session.HasKey("accessToken")){
                    return false
                }
                if (this.session.HasKey("exp2")){
                    if (A_now > this.session.exp2)
                        return false
                }

                return true
            }
        }
        getSession()
        {
            ihtml := this.doc.getElementById("kivra-fetch-getSession").innerHTML
            this.doc.getElementById("kivra-fetch-getSession").innerHTML := "<div class='spinner-border spinner-border-sm'></div>"
            this.doc.getElementById("kivra-fetch-getSession").disabled := true
            browser := this.doc.getElementById("PreferredBrowser").value
            session := kivraFetchToken(browser)
            if (session.hasKey("error")){
                this.showError(session.error)
                this.doc.getElementById("kivra-fetch-getSession").innerHTML := ihtml
                this.doc.getElementById("kivra-fetch-getSession").disabled := false
                return
            }
            this.session := session

            if !(this.isInloggad){
                this.doc.getElementById("kivra-fetch-getSession").innerHTML := ihtml
                this.doc.getElementById("kivra-fetch-getSession").disabled := false
                msg := "Sessionen har gått ut, logga in igen."
                this.ShowError(msg)
                return {"error":msg}
            }
                html = 
                (LTRIM JOIN
                <table class="table table-sm">
                    <tbody>
                    {{rows}}
                    </tbody>
                </table>
                )

            this.receipts := this.getReceipts()
            this.receipts := this.getReceipts(this.receipts.total)
            this.session.totalReceipts := this.receipts.total
            for k,v in session
            {
              rows .= "<tr><th>" k "</th><td>" v "</td></tr>"  
            }

            html := StrReplace(html,"{{rows}}",rows)
            this.doc.getElementById("sessionInfo").innerHTML := html
            this.doc.getElementById("kivra-fetch-getSession").innerHTML := ihtml
            this.doc.getElementById("kivra-fetch-getSession").disabled := false
            this.receiptsList()
            this.saveReceiptsIndex()
            
        }
        deleteReceipt(id)
        {
            key := StrReplace(id,"kivra-fetch-delete-")
            if (fileExist(this.savedReceipts[key])){
                FileDelete % this.savedReceipts[key]
                msgbox % "tagit bort-" key
            } 
                this.loadsavedReceipts()
                this.receiptsList()
        }
        showReceipt(id)
        {
            key := StrReplace(id,"kivra-fetch-show-")
            FileRead, file, % this.savedReceipts[key]
            file := JSON.LOAD(file)
            array_gui(file)
        }
        receiptsList(limit := 100)
        {
                limit := (limit > this.receipts.list.Count() ? this.receipts.list.Count() : limit)
                html = 
                (LTRIM JOIN
                <div class="card">
                <div class="card-body">
                <div class="row">
                <div class="col mb-3">
                <div class="row">
                    <div class="col">
                <h3>
                <i class="bi bi-receipt mr-2 text-primary"></i>
                <span class="mr-2">Kvitton</span>
                <span class="mr-2 badge badge-primary">{{totalAmount}} kr</span> 
                <span class="mr-2 badge badge-primary">{{total}} st</span> 
                <!--<span class="mr-2 badge badge-primary">{{period}}</span>-->
               
                </h3>
                </div>
                <div class="col">
                 <button class="btn btn-outline-primary float-right" id="kivra-fetch-spara-alla">Spara alla</button>
                </div>
                </div>
                </div>
                </div>
                <div class="row">
                <div class="col">
               <small> Visar <span id="limit">%limit%</span> av {{total}}<span class='ml-2'>{{period}}</span><span class='ml-2'>{{totalAmount2}}</span></small>
                </div>
                </div>
                <div class="row">
                <div class="col mb-3">
                <div style="overflow-y: auto;height: 60vh;" id='receiptsscroll'>
                <table class="table table-sm" >
                    <thead class="">
                    <tr>
                    <th>#</th>
                    <th>Datum</th>
                    <th>Tid</th>
                    <th>Summa</th>
                    <th>Butik</th>
                    <th><!--Sparad--></th>
                    <th><!--Actions--></th>
                    </tr>
                    </thead>
                    <tbody >
                    {{rows}}
                    </tbody>
                </table>
                </div>
                </div>
                </div>
                </div>
                </div>
                )
                
                totalAmount2 := 0
                rows := ""
                for k,v in this.receipts.list
                {
                    _index := A_index
                    if (A_index > limit)
                        break
                    if (this.savedReceipts.hasKey(v.key)){
                        v.__saved := true
                    }
                    totalAmount2 += StrReplace(StrReplace(v.amount," kr"),",",".")
                    d := strSplit(v.date,",")
                    v.datum := d[1]
                    row := "<tr>"
                    row .= "<th>" _index "</th>"
                    row .= "<td>" d[1] "</td>"
                    row .= "<td>" d[2] "</td>"
                    row .= "<td>" v.amount "</td>"
                    row .= "<td>" v.storeName "</td>"
                    row .= "<td id='kivra-fetch-saved-" v.key "'><div class='btn-group btn-group-sm' title='" (v.__saved ? "sparad" : "inte sparad" )  "' role='group'><button class='btn btn-link' disabled><i class='bi bi-file-earmark-check text-" (v.__saved ? "success" : "danger" )  "'></i></button></div></td>"
                    row .= "<td>" this._actions(v) " </td>" 
                    row .= "</tr>"
                    rows .= row
                }

                totalAmount2 := Round(totalAmount2,2)
                total := this.receipts.list.Count()
                if (limit < total){
                    rows .= "<tr><td colspan='7'><button class='btn btn-outline-primary btn-sm' id='kivra-fetch-show-more'>Visa mer</button></td></tr>"
                } else {
                    rows .= "<tr><td colspan='7'><button class='btn btn-outline-primary btn-sm' id='kivra-fetch-table-scrolltop'>Till toppen</button></td></tr>"
                }
                pEnd := this.receipts.list[_index].date
                pEnd := strSplit(pEnd,",")
                pStart := this.receipts.list[1].date
                pStart := strSplit(pStart,",")
                period := "<span class='mr-2'>" pStart[1]   "</span><strong>- </strong><span class=''>" pEnd[1]  "</span>"
                html := StrReplace(html,"{{rows}}",rows)
                html := StrReplace(html,"{{totalAmount2}}",totalAmount2 " kr")
                html := StrReplace(html,"{{totalAmount}}",this.totalAmount())
                html := StrReplace(html,"{{total}}",total)
                html := StrReplace(html,"{{period}}",period)
                this.doc.getElementById("receiptsList").innerHTML := html
        }
        scrollToTop(src)
        { ;kivra-fetch-table-scrolltop
            element := this.doc.getElementById("receiptsscroll")
            element.scrollTop := 0
            ;element.scrollTo(0,0)
        }
        showMore(src)
        {
            cLimit := this.doc.getElementById("limit").innerText
            cLimit += 100
            this.receiptsList(cLimit)
            element := this.doc.getElementById("receiptsscroll")
            element.scrollTop := element.scrollHeight
        }
        totalAmount()
        {
            totalAmount := 0
            for k,v in this.receipts.list
               totalAmount += StrReplace(StrReplace(v.amount," kr"),",",".")
            return Round(totalAmount,2)
        }
        _actions(v)
        {
                actions =
                (LTRIM Join
                <div class="btn-group btn-group-sm" role="group">
               
                {{btns}}
                </div>
                )
                btns =
                (
                <button id="kivra-fetch-save-{{key}}" class="btn btn-link" title="Spara"><i class='bi bi-save2'></i></button>
                <button id="kivra-fetch-show-{{key}}" class="btn btn-link" title="Visa"><i class='bi bi-file-earmark-play'></i></button>
                <button id="kivra-fetch-delete-{{key}}" class="btn btn-link" title="Ta bort"><i class='bi bi-trash text-danger'></i></button>
                )
                btns := StrSplit(btns,"`n")
                
                _btns := (v.__saved ? btns[2] btns[3] : btns[1]) 
                ;_btns .=  (v.__saved ? "" : btns[1]) 
                actions := StrReplace(actions,"{{btns}}",_btns)
                actions := StrReplace(actions,"{{key}}",v.key)
                
                return actions

        }
        fetchToken()
        {
            static kivraGetTokenScriptPath := A_ScriptDir "\ahk\cmd\getKivraToken.ahk"

                if (fileExist(kivraGetTokenScriptPath)){
                    FileRead,script, % kivraGetTokenScriptPath
                    session := JSON.LOAD(this.ExecScript(script))
                    if (session.HasKey("error")){
                        msgbox % "Message: " session.msg "`nError: " session.error "`nNext: " session.next 
                        
                        ExitApp
                    }
                    return session
                    
                }
        }
        ExecScript(Script, Wait:=true)
        {
            shell := ComObjCreate("WScript.Shell")
            exec := shell.Exec("AutoHotkey.exe /ErrorStdOut *")
            exec.StdIn.Write(script)
            exec.StdIn.Close()
            
            if (wait){
                
                while (exec.status = "0")
                {
                    ToolTip, % A_Index "`n" exec.ProcessID "`n" exec.status
                    if (A_index > 4000){
                        exec.Terminate()
                        return {"msg":"Failed to get token","error":"Timeout","next":"Exiting."}
                    }
                        
                    sleep 10
                }
                return exec.StdOut.ReadAll()
            }
            
        }
        getReceipts(limit := 20)
        {
            if !(this.isInloggad){
                msg := "Sessionen har gått ut, logga in igen."
                this.ShowError(msg)
                return {"error":msg}
            }
            payload =
            (LTRIM Join
            {"operationName":"GetReceipts","variables":
            {"limit":%limit%,"offset":0,"search":null,"organized":true},
            "query":"query GetReceipts($search: String, $limit: Int, $offset: Int, $organized: Boolean) 
            {\n  receipts(search: $search, limit: $limit, offset: $offset, organized: $organized) 
            {\n    total\n    offset\n    limit\n    ... on OrganizedReceiptList 
            {\n      list 
            {\n        ...receiptItemFields\n        ... on HeaderListItem 
            {\n          header\n          __typename\n        }\n        __typename\n      }\n      __typename\n    }\n    ... on UnorganizedReceiptList 
            {\n      list {\n        ...receiptItemFields\n        __typename\n      }\n      __typename\n    }\n    __typename\n  }\n}\n\nfragment receiptItemFields on ReceiptListItem 
            {\n  labels 
            {\n    type\n    text\n    __typename\n  }\n  actions {\n    type\n    text\n    __typename\n  }\n  amount\n  date\n  key\n  logo {\n    publicUrl\n    __typename\n  }\n  storeName\n  contentIndex\n  __typename\n}\n"}
            )
            session := this.session 
            headers := { "accept": "*/*"
                        ,"accept-language": "sv"
                        ,"authorization": "Bearer " session.accessToken
                        ,"content-type": "application/json"
                        ,"sec-ch-ua": "Not A;Brand;v=99,Chromium;v=101,Google Chrome;v=101"
                        ,"sec-ch-ua-mobile": "?0"
                        ,"sec-ch-ua-platform": "Windows"
                        ,"sec-fetch-dest": "empty"
                        ,"sec-fetch-mode": "cors"
                        ,"sec-fetch-site": "same-site"
                        ,"x-actor-key": session.userID
                        ,"x-actor-type": "user"
                        ,"referrer": "https://inbox.kivra.com/"}

                                req := ComObjCreate("MSXML2.XMLHTTP.6.0")
                            
                                req.Open("POST","https://bff.kivra.com/graphql",true)
                                For k,v in headers
                                        req.SetRequestHeader(k,v)           
                                    
                                
                                e := 0
                                req.Send(payload)
                                while req.readystate != 4
                                e++



                                r := JSON.LOAD(req.ResponseText)
                                newList := {}
                                for k,v in r.data.receipts.list
                                {
                                    if (v.__typename = "ReceiptListItem")
                                        newList.push(v)
                                }
                                for k,v in newList
                                {
                                    if (this.savedReceipts.HasKey(v.key)){
                                        v.__saved := true
                                    } else {
                                        v.__saved := false
                                    }
                                }


                                r.data.receipts.list := newList
                               
                                return r.data.receipts
                                ;return JSON.LOAD(req.ResponseText)            
        }   
        getReceipt(key)
        {
            if !(this.isInloggad){
                msg := "Sessionen har gått ut, logga in igen."
                this.ShowError(msg)
                return {"error":msg}
            }
            payload =
            (LTRIM Join
            {"operationName":"GetReceipt","variables":{"key":"%key%"},"query":"query GetReceipt($key: String!) {\n  receipt(key: $key) {\n    key\n    senderKey\n    campaigns {\n      image {\n        publicUrl\n        __typename\n      }\n      title\n      key\n      height\n      width\n      destinationUrl\n      __typename\n    }\n    card {\n      title\n      store {\n        name\n        logo {\n          publicUrl\n          __typename\n        }\n        __typename\n      }\n      totalPurchaseAmount\n      date {\n        property\n        value\n        subRows {\n          property\n          value\n          __typename\n        }\n        __typename\n      }\n      __typename\n    }\n    status {\n      message\n      __typename\n    }\n    content {\n      header {\n        totalPurchaseAmount\n        subAmounts\n        date\n        text\n        labels {\n          type\n          text\n          __typename\n        }\n        logo {\n          publicUrl\n          __typename\n        }\n        __typename\n      }\n      footer {\n        text\n        __typename\n      }\n      items {\n        allItems {\n          text\n          items {\n            type\n            ... on ProductListItem {\n              ...productFields\n              __typename\n            }\n            ... on GeneralDepositListItem {\n              amount\n              isRefund\n              description\n              __typename\n            }\n            ... on GeneralDiscountListItem {\n              amount\n              isRefund\n              text\n              __typename\n            }\n            __typename\n          }\n          __typename\n        }\n        noBonusItems {\n          text\n          items {\n            type\n            ... on ProductListItem {\n              ...productFields\n              __typename\n            }\n            __typename\n          }\n          __typename\n        }\n        returnedItems {\n          text\n          items {\n            type\n            ... on ProductReturnListItem {\n              name\n              cost\n              quantity\n              deposits {\n                description\n                amount\n                isRefund\n                __typename\n              }\n              costModifiers {\n                description\n                amount\n                isRefund\n                __typename\n              }\n              connectedReceipt {\n                receiptKey\n                description\n                isParentReceipt\n                __typename\n              }\n              identifiers\n              __typename\n            }\n            __typename\n          }\n          __typename\n        }\n        __typename\n      }\n      storeInformation {\n        text\n        storeInformation {\n          property\n          value\n          subRows {\n            property\n            value\n            __typename\n          }\n          __typename\n        }\n        __typename\n      }\n      paymentInformation {\n        text\n        totals {\n          text\n          totals {\n            property\n            value\n            subRows {\n              property\n              value\n              __typename\n            }\n            __typename\n          }\n          __typename\n        }\n        paymentMethods {\n          text\n          methods {\n            type\n            information {\n              property\n              value\n              subRows {\n                property\n                value\n                __typename\n              }\n              __typename\n            }\n            __typename\n          }\n          __typename\n        }\n        customer {\n          text\n          customer {\n            property\n            value\n            subRows {\n              property\n              value\n              __typename\n            }\n            __typename\n          }\n          __typename\n        }\n        cashRegister {\n          text\n          cashRegister {\n            property\n            value\n            subRows {\n              property\n              value\n              __typename\n            }\n            __typename\n          }\n          __typename\n        }\n        __typename\n      }\n      __typename\n    }\n    actions {\n      type\n      text\n      __typename\n    }\n    __typename\n  }\n}\n\nfragment productFields on ProductListItem {\n  name\n  cost\n  quantity\n  deposits {\n    description\n    amount\n    isRefund\n    __typename\n  }\n  costModifiers {\n    description\n    amount\n    isRefund\n    __typename\n  }\n  identifiers\n  __typename\n}\n"}
            )
            session := this.session 
            headers := { "accept": "*/*"
                        ,"accept-language": "sv"
                        ,"authorization": "Bearer " session.accessToken
                        ,"content-type": "application/json"
                        ,"sec-ch-ua": "Not A;Brand;v=99,Chromium;v=101,Google Chrome;v=101"
                        ,"sec-ch-ua-mobile": "?0"
                        ,"sec-ch-ua-platform": "Windows"
                        ,"sec-fetch-dest": "empty"
                        ,"sec-fetch-mode": "cors"
                        ,"sec-fetch-site": "same-site"
                        ,"x-actor-key": session.userID
                        ,"x-actor-type": "user"
                        ,"referrer": "https://inbox.kivra.com/"}

                        req := ComObjCreate("MSXML2.XMLHTTP.6.0")
                        req.Open("POST","https://bff.kivra.com/graphql",true)
                        For k,v in headers
                                req.SetRequestHeader(k,v)           
                            
                        
                        e := 0
                        req.Send(payload)
                        while req.readystate != 4
                        e++
                        return JSON.LOAD(req.ResponseText)

        }                     
    

}


    




kivraFetchToken(PreferredBrowser := "chrome.exe"){
static kivraGetTokenScriptPath := A_ScriptDir "\ahk\cmd\getKivraToken.ahk"

    if (fileExist(kivraGetTokenScriptPath)){
        FileRead,script, % kivraGetTokenScriptPath
        script := StrReplace(script,"{{PreferredBrowser}}",PreferredBrowser)
                

        session := JSON.LOAD(ExecScript(script))
        if (session = ""){
            return {"error":"failed to get token"}
        }

        return session
    }
    

}




ExecScript(Script, Wait:=true)
{
    shell := ComObjCreate("WScript.Shell")
    exec := shell.Exec("AutoHotkey.exe /ErrorStdOut *")
    exec.StdIn.Write(script)
    exec.StdIn.Close()
    this.exec := exec
    if (wait){
        
        while (exec.status = "0")
        {
            ;ToolTip, % A_Index "`n" exec.ProcessID
            if (A_index > 4000){
                exec.Terminate()
                 return {"error":"Failed to get token,timeout."}
            }
                
            sleep 10
        }
        return exec.StdOut.ReadAll()
    }
    

}















