DetectHiddenWindows, on
#NoEnv  

#MaxMem 700
SendMode Input  

SetMouseDelay -1
SetControlDelay -1
SetBatchLines -1

#SingleInstance, force

global pptr
global session


PreferredBrowser := "{{PreferredBrowser}}" ; msedge.exe
PreferredBrowser2 := "msedge.exe"
availableSupportedBrowsers := puppeteer.chromiumPaths()

if (availableSupportedBrowsers.haskey(PreferredBrowser)){
	browser := PreferredBrowser
} else {
	if (availableSupportedBrowsers.haskey(PreferredBrowser2)){
		browser := PreferredBrowser2
	} else  {
			stdout := FileOpen("*", "w `n")
			stdout.WriteLine(JSON.DUMP({"error":"Hittar inte " PreferredBrowser " eller " PreferredBrowser2 }))  
			ExitApp 
	}

}


pptr := new puppeteer(debugPort:= (options.debugPort ? options.debugPort : 9323)
                                                ,dataDir := ""
                                                ,windowsize := "860x860"
                                                ,url := "https://accounts.kivra.com/"
                                                ,domains := ""
                                                ,console := false
                                                ,exe :=  browser ;"chrome.exe"  ;"chrome.exe"   ;"msedge.exe"
                                                ,flags := ["--force-dark-mode"])
waitForUrl(pptr,"https://inbox.kivra.com/user/")
session := kivraGetToken(pptr)

pptr.kill()






session.exp := gDate(session.expiryTime)
session.acquiredTime := A_now
session.exp2 := diff15Minutes()


;Array_Gui(session)
pptr.kill()
stdout := FileOpen("*", "w `n")
stdout.WriteLine(JSON.DUMP(session))    

exitapp  

exits:

return

diff15Minutes()
{
    time := ""
	time += 15, Minutes
    return time
}

gDate(unixTimestamp)
{
		;1613438994

			;unixTimestamp := (unixTimestamp/1000)
			returnDate = 19700101000000
			returnDate += unixTimestamp, s
			returnDate += 7200, s
			FormatTime, returnDate, % returnDate, yyyyMMddhhmmss
			;returnDate += 1, d
			;FormatTime, returnDate,returnDate, Time
			return returnDate 
			yyyy := SubStr(returnDate,1,4)
			mm   := SubStr(returnDate,5,2)
			dd	 := SubStr(returnDate,7,2)
			return yyyy "-" mm "-" dd

}


kivraGetToken(pptr){


    js = 
    (LTRIM JOIN
    window.sessionStorage['kv.session'];
    )

    while !(instr( session := pptr.Evaluate(js).value,"accessToken")){

    sleep 1000
    ;tooltip % _url
    } 

    ;MsgBox, % session
    session := JSON.LOAD(session)
    ;Array_Gui(session)
    return session
}



waitForUrl(pptr,url){

        ; https://inbox.kivra.com/user/
        ;sleep 1000
        js = 
        (LTRIM JOIN
        document.URL;
        )

        while !(instr( _url := pptr.Evaluate(js).value,url)){
			if (_url = "disconnected"){
				pptr.kill()
				stdout := FileOpen("*", "w `n")
				stdout.WriteLine(JSON.DUMP(session))  
				;msgbox % url
				exitapp
			}
        sleep 1000

        } 

        return true

}








class WSSession extends EventEmitter {
	 __New(host, port := 80, url := "/", subprotocol := "",main :="")
    {
        this.host := host
        this.port := port
        this.url := url
        this.subprotocol := subprotocol
        this.main := main
        this.HTTP := new HTTPClient(this.host, this.port, ObjBindMethod(this, "HandleHTTP"))

        this.DoHandshake()
    }
    
    DoHandshake()
    {
        UpgradeRequest := new HTTPRequest()

        this.key := createHandshakeKey()
        
        UpgradeRequest.headers["Host"] := this.host . ":" . this.port
        UpgradeRequest.headers["Origin"] := "http://" . this.host . ":" . this.port
        UpgradeRequest.headers["Connection"] := "Upgrade"
        UpgradeRequest.headers["Upgrade"] := "websocket"
        UpgradeRequest.headers["Sec-WebSocket-Key"] := this.key

        if(this.subprotocol)
        {
            request.headers["Sec-WebSocket-Protocol"] := this.subprotocol
        }

        UpgradeRequest.headers["Sec-WebSocket-Version"] := 13
        
        UpgradeRequest.method := "GET"
        UpgradeRequest.url := this.url

        this.HTTP.SendRequest(UpgradeRequest)
    }
    
    HandleHTTP(HTTP, Response)
    {
        if(Response.statuscode == 101)
        {
            if(sec_websocket_accept(this.key) != Response.headers["Sec-WebSocket-Accept"]) {
                this.main.console.log("WS Handshake error: key returned from server doesn't match.")
                return
            }
            
			WS := this.HTTP
			ObjSetBase(WS, WSClient)
			this.WS := WS

			this.WS.OnRequest := ObjBindMethod(this, "HandleWS")
        }
        else
        {
            this.main.console.log(response.raw)
        }
    }

	HandleWS(Response) {
		OpcodeName := WSOpcodes.ToString(Response.Opcode)

		if (ObjGetBase(this).HasKey("On" OpcodeName)) {
			this["On" OpcodeName](Response)
		}
		this.main.console.log(response)
		return this.Emit(Response.Opcode, Response)
	}

	OnPing(Response) {
		; To handle a PING, we just need to reply with a PONG containing the exact same application data as the pong

		this.WS.SendFrame(WSOpcodes.Pong, Response.pPayload, Response.PayloadSize)

		this.main.console.log("Pong'd")
	}

	OnClose(Response) {
		; To handle a CLOSE, we just reply with a CLOSE and then close the socket

		this.WS.SendFrame(WSOpcodes.Close)

		this.WS.Disconnect()

		this.main.console.log("Closed")
	}

	SendText(Message) {
		this.WS.SendText(Message)
	}
}

createHandshakeKey()
{
	VarSetCapacity(CSPHandle, 8, 0)
	VarSetCapacity(RandomBuffer, 16, 0)
	DllCall("advapi32.dll\CryptAcquireContextA", "Ptr", &CSPHandle, "UInt", 0, "UInt", 0, "UInt", PROV_RSA_AES := 0x00000018,"UInt", CRYPT_VERIFYCONTEXT := 0xF0000000)
	DllCall("advapi32.dll\CryptGenRandom", "Ptr", NumGet(&CSPHandle, 0, "UInt64"), "UInt", 16, "Ptr", &RandomBuffer)
	DllCall("advapi32.dll\CryptReleaseContext", "Ptr", NumGet(&CSPHandle, 0, "UInt64"), "UInt", 0)
	
	return Base64_encode(&RandomBuffer, 16)
}

sec_websocket_accept(key)
{
	key := key . "258EAFA5-E914-47DA-95CA-C5AB0DC85B11" ; Chosen by fair dice roll. Guaranteed to be random.
	sha1 := sha1_encode(key)
	pbHash := sha1[1]
	cbHash := sha1[2]
	b64 := Base64_encode(&pbHash, cbHash)
	return b64
}


class WSClient extends SocketTCP
{
	PendingFragmentedRequest := 0
	
	HandleRequest(Request) {
		this.OnRequest.Call(Request)
	}
	
	
	    OnRecv() {   
        DataSize := this.MsgSize()
        VarSetCapacity(Data, DataSize + 1) ; One extra byte, so we can null terminate TEXT messages
        this.Recv(Data, DataSize)

        Request := new WSRequest(&Data, DataSize)

        if (Request.Opcode & 0x10) {
            ; Control frame, skip fragmentation handling

            this.HandleRequest(Request)            
        }
        else if (Request.Opcode != 0 && Request.Final) {
            ; Opcode that can be fragmented, but this is the final request of the fragmented message.
            ; Meaning that this is both the start and end of a fragmented message, making it the 
            ;  only fragment of that message.

            this.HandleRequest(Request)
        }
        else {
            ; The start or middle/end of a fragmented request

            if (IsObject(this.PendingFragmentedRequest)) {
                ; Middle/end of a fragmented request

                this.PendingFragmentedRequest.Update(Request)
                
                if (this.PendingFragmentedRequest.Final) {
                    ; Middle *and* end of a fragmented request

                    this.HandleRequest(this.PendingFragmentedRequest)
                    this.PendingFragmentedRequest := 0
                }

                ; else { middle of fragmented request }
            }
            else {
                ; Start of a fragmented request

                if (Request.Opcode = 0) {
                    Throw Exception("The server replied with a fragmented request starting with an opcode of 0")
                }

                this.PendingFragmentedRequest := new WSFragmentedRequest(Request)
            }
        }
    }
	
	SendFrame(Opcode, pMessageBuffer := 0, MessageSize := 0) {
		Response := new WSResponse(Opcode, pMessageBuffer, MessageSize)
		ResponseBuffer := Response.Encode()
		
		this.Send(ResponseBuffer.GetPointer(), ResponseBuffer.Length)
	}
	
	SendText(Message) {
		MessageSize := StrPut(Message, "UTF-8") - 1
		VarSetCapacity(MessageBuffer, MessageSize)
		StrPut(Message, &MessageBuffer, MessageSize, "UTF-8")
		
		this.SendFrame(WSOpcodes.Text, &MessageBuffer, MessageSize)
	}
}


class HTTPClient extends SocketTCP
{
	__New(IP, Port, OnResponse) {
		SocketTCP.__New.Call(this)
		
		this.OnResponse := OnResponse
		
		this.Connect([IP, Port])
	}
	
	SendRequest(Request) {
		this.SendText(Request.Generate())
	}
	
	PendingResponse := false
	
	OnRecv() {
		ResponseSize := this.MsgSize()
		ResponseText := this.RecvText()
		if (IsObject(this.PendingResponse) && !this.PendingResponse.Done) {
			; Get data and append it to the existing response body
			
			Response := this.PendingResponse
			
			Response.BytesLeft -= ResponseSize
			Response.Body .= ResponseText
		} 
		else {
			; Parse new response
			
			Response := new HTTPResponse(ResponseText)
			
			TotalSize := Response.Headers["Content-Length"] + 0
			Response.BytesLeft := TotalSize
			
			if (Response.Body) {
				Response.BytesLeft -= StrPut(Response.Body, "UTF-8") ; Response.BytesLeft -= SizeOf(Response.Body.Encode('UTF-8'))
			}
		}
		
		if (Response.BytesLeft <= 0) {
			Response.Done := true
			this.OnResponse(Response)
		}
		else {
			this.PendingResponse := Response
		}
	}
}

class HTTPRequest
{
    __new(method := "GET", url := "/", headers := "")
    {
        if(headers == "")
        {
            headers := {}
        }
        this.method := method
        this.headers := headers
        this.url := url
        this.protocol := "HTTP/1.1"
    }
    
    Generate()
    {
        body := this.method . " " . this.url . " " . this.protocol . "`r`n"
        
        for key, value in this.headers {
            StringReplace,value,value,`n,,A
            StringReplace,value,value,`r,,A
            body .= key . ": " . value . "`r`n"
        }
        body .= "`r`n"
        
        return body
    }
}

class HTTPResponse
{
    __new(data)
    {
        if (data)
        this.Parse(data)
    }
    
    GetPathInfo(top)
    {
        results := []
        while (pos := InStr(top, " ")) {
            results.Insert(SubStr(top, 1, pos - 1))
            top := SubStr(top, pos + 1)
        }
        this.method := results[1]
        this.statuscode := Uri.Decode(results[2])
        this.protocol := top
    }
    
    Parse(data) {
        this.raw := data
        data := StrSplit(data, "`n`r")
        headers := StrSplit(data[1], "`n")
        this.body := LTrim(data[2], "`n")
        this.GetPathInfo(headers.Remove(1))
        this.headers := {}
        
        for i, line in headers {
            pos := InStr(line, ":")
            key := SubStr(line, 1, pos - 1)
            val := Trim(SubStr(line, pos + 1), "`n`r ")
            
            this.headers[key] := val
        }
    }
}

/*
	this is where we hide the ugly code, Yeah it gets uglier...
	acording to the Websocket RFC: http://tools.ietf.org/html/rfc6455
	there's lots of bits that we need to scrub before we can get the message data
	according to ammount of data the message may be split in multiple data frames
	as well as change the format of the data frame
	
	
	Frame format:
	0               1               2               3               4    bytes
	0                   1                   2                   3
	0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
	+-+-+-+-+-------+-+-------------+-------------------------------+
	|F|R|R|R| opcode|M| Payload len |    Extended payload length    |
	|I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
	|N|V|V|V|       |S|             |   (if payload len==126/127)   |
	| |1|2|3|       |K|             |                               |
	+-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
	|     Extended payload length continued, if payload len == 127  |
	+ - - - - - - - - - - - - - - - +-------------------------------+
	|                               |Masking-key, if MASK set to 1  |
	+-------------------------------+-------------------------------+
	| Masking-key (continued)       |          Payload Data         |
	+-------------------------------- - - - - - - - - - - - - - - - +
	:                     Payload Data continued ...                :
	+ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
	|                     Payload Data continued ...                |
	+---------------------------------------------------------------+
	
	OpCodes: 
	0x8 Close
	0x9 Ping
	0xA Pong
	
	Payload data OpCodes:
	0x0 Continuation
	0x1 Text
	0x2 Binary
	
	
	
	references: 
	http://tools.ietf.org/html/rfc6455
	https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API/Writing_WebSocket_servers
	https://www.iana.org/assignments/websocket/websocket.xhtml
	
	implementation references:
	Lua: https://github.com/lipp/lua-websockets/blob/master/src/websocket/frame.lua
	Python: https://github.com/aaugustin/websockets/blob/main/src/websockets/frames.py
	JS: https://github.com/websockets/ws/blob/master/lib/receiver.js
	JS: https://github.com/websockets/ws/blob/master/lib/sender.js
	
	when reading this code, keep in mind:
	1 - there's no way to read binary in AHK, only bytes at a time (so there's lots of AND masking going on)
	2 - arrays start at 1
*/

OpCodes := {CONTINUATION:0x0,TEXT:0x1,BINARY:0x2,CLOSE:0x8,PING:0x9,PONG:0xA}

class WSOpcodes {
		static CONTINUATION := 0x0
		static TEXT := 0x1
		static BINARY := 0x2
		static CLOSE := 0x8
		static PING := 0x9
		static PONG := 0xA

		ToString(Value) {
			for Name, NameValue in WSOpcodes {
				if (Value = NameValue) {
					return Name
				}
			}
		}
	}

/*
	MDN says: 
	"
	1. Read bits 9-15 (inclusive) and interpret that as an unsigned integer. If it's 125 or less, then that's the length; you're done. If it's 126, go to step 2. If it's 127, go to step 3.
	2. Read the next 16 bits and interpret those as an unsigned integer. You're done.
	3. Read the next 64 bits and interpret those as an unsigned integer. (The most significant bit must be 0.) You're done.
	"
	So unfortunatelly using NumGet UShort and UInt64 doesn't work...
*/
Uint16(a, b) {
	return a << 8 | b
}
Uint64(a, b, c, d) {
	return a << 24 | b << 16 | c << 8 | d    
}
Uint16ToUChar(c) {
	a := c >> 8
	b := c & 0xFF
	return [a, b]
}

Uint64ToUChar(e) {
	a := e >> 24
	b := e >> 16
	c := e >> 8
	d := c & 0xFF
	return [a, b, c, d]
}

class WSDataFrame{
	encode(message) {
		length := strlen(message)
		if(length < 125) {
			byteArr := [129, length]
			buf := new Buffer(length + 2)
			Loop, Parse, message
			byteArr.push(Asc(A_LoopField))
			VarSetCapacity(result, byteArr.Length())
			For, i, byte in byteArr
			NumPut(byte, result, A_Index - 1, "UInt")
			buf.Write(&result, length + 2)
		}
		return buf
	}
}

class ReadOnlyBufferBase {
	ReadString(Offset, Length := -1) {
		if (Length > 0) {
			return StrGet(this.pData + Offset, Length, "UTF-8")
		}
		else {
			return StrGet(this.pData + Offset, "UTF-8")
		}
	}
	
	__Call(MethodName, Params*) {
		
		if (RegexMatch(MethodName, "O)Read(\w+)", Read) && Read[1] != "String") {
			return NumGet(this.pData + 0, Params[1], Read[1])
		}
	}
}

MoveMemory(pTo, pFrom, Size) {
   DllCall("RtlMoveMemory", "Ptr", pTo, "Ptr", pFrom, "UInt", Size)
}

class WSRequest extends ReadOnlyBufferBase {
	__New(pData, DataLength){
		this.pData := pData
		this.DataLength := DataLength
		
		
		this.ParseHeader()
		this.UnMaskPayload()
		NumPut(0, this.pPayload + 0, this.PayloadSize, "UChar") 
		; Null terminate for TEXT opcodes, since stupid `StrGet()` takes a number of characters, and not a number of bytes.
		; "Ah yeah, I know loads of protocols that communicate in terms of how many UTF-8 *characters* are in a message"
		
		; This is safe, since `WSClient.OnRecv()` allocates `DataSize + 1` bytes (specifically for us)
		this.PayloadText := StrGet(this.pPayload, "UTF-8", this.PayloadSize)
		;Console.log("this.PayloadText : " this.PayloadText)
	}
	
	ParseHeader(){
		OpcodeAndFlags := this.ReadUChar(0)
		
		;this.Final := OpcodeAndFlags & 0x80 ? True : False ; for fragment this does not support
		this.Final := this.ReadUChar(15) & 0x20 ? True : False ; working idk why
		
		this.rsv1 := OpcodeAndFlags & 0x40 ? True : False
		this.rsv2 := OpcodeAndFlags & 0x20 ? True : False
		this.rsv3 := OpcodeAndFlags & 0x10 ? True : False
		
		this.Opcode := OpcodeAndFlags & 0xF
		
		MaskAndLength := this.ReadUChar(1)
		
		this.IsMasked := MaskAndLength & 0x80 ? True : False
		
		this.PayloadSize := MaskAndLength & 0x7F
		
		LengthSize := 0
		
		if (this.PayloadSize = 0x7E) && ( this.opcode =  WSOpcodes.Text) {
			LengthSize := 2
			this.PayloadSize := DllCall("Ws2_32\ntohs", "UShort", this.ReadUShort(2), "UShort")
		} 
		else if (this.PayloadSize = 0x7F) && ( this.opcode =  WSOpcodes.Text){
			LengthSize := 8
			this.PayloadSize := DllCall("Ws2_32\ntohll", "UInt64", this.ReadUInt64(2), "UInt64")
		}
		else if ( this.opcode !=  WSOpcodes.Text)
		{
			LengthSize := -2
			this.PayloadSize := DllCall("Ws2_32\ntohl", "UShort", this.ReadUlong(2), "UShort")
		}
		
		this.pKey := this.pData + 2 + LengthSize  ; Only actually used if we are masked, otherwise it is equal to pPayload
		this.pPayload := this.pKey + (this.IsMasked * 4)
	}
	
	UnMaskPayload() {
		if (!this.IsMasked) {
			Return
		}
		
		loop, % this.PayloadSize {
			Index := A_Index - 1
			
			Old := NumGet(this.pPayload + 0, Index, "UChar")
			Mask := NumGet(this.pKey + 0, Index & 3, "UChar")
			
			NumPut(Old ^ Mask, this.pPayload + 0, Index, "UChar")
		}
	}
}

class WSFragmentedRequest extends ReadOnlyBufferBase {
	Fragments := []
	Final := false
	PayloadSize := 0
	
	; Buffer that holds the data from all fragments received so far, but is only updated when it is actually used
	FullPayloadFragmentCount := 0
	FullPayloadBufferSize := 0
	FullPayloadBuffer := ""
	
	__New(FirstFragment) {
		this.Fragments.Push(FirstFragment)
		this.PayloadSize += FirstFragment.PayloadSize
		
		this.Opcode := FirstFragment.Opcode
	}
	
	Update(NextFragment) {
		if (this.Final) {
			Throw Exception("An additional fragment was added to a websocket request which was already complete")
		}
		
		this.Fragments.Push(NextFragment)
		this.PayloadSize += NextFragment.PayloadSize
		
		
		if (NextFragment.Final) {
			this.Final := true
		}
		
		if (NextFragment.Opcode != 0) {
			; i disabled it coz rules have been changed
			;Throw Exception("The server replied with a request fragment containing a non-zero opcode")
		}
	}
	
	pData[] {
		get {
			; Someone wants this request's data
			
			if (this.FullPayloadBufferSize != this.Fragments.Count()) {
				this.SetCapacity("FullPayload", this.PayloadSize)
				
				pFullPayload := this.GetAddress("FullPayload")
				Offset := this.FullPayloadBufferSize
				;console.log(this.FullPayloadFragmentCount "|" this.Fragments.Count())
				loop, % this.Fragments.Count() - this.FullPayloadFragmentCount {
					Index := this.FullPayloadFragmentCount + A_Index - 1
					
					CopyFragment := this.Fragments[Index]
					
					MoveMemory(pFullPayload + Offset, CopyFragment.pPayload, CopyFragment.PayloadSize)
					
					Offset += CopyFragment.PayloadSize
				}
				
				this.FullPayloadBufferSize := this.PayloadSize
				this.FullPayloadFragmentCount := this.Fragments.Count()
				
				if (this.Opcode = WSOpcodes.Text) {
					this.PayloadText := StrGet(pFullPayload, "UTF-8", this.PayloadSize)
				}
			}
			
		}
	}
	
}

class WSResponse {
	__new(opcode := 0x01, pMessage := "", length := 0, fin := True){
		this.opcode := opcode
		this.fin := fin
		this.pMessage := pMessage
		this.length := length
	}
	
	encode() {
		byte1 := (this.fin? 0x80 : 0x00) | this.opcode
		
		if(this.length < 127) {
			byteArr := [byte1, this.length]
		
		} else if(this.length <= 65535) {
			lengthBytes := Uint16ToUChar(this.length)
			byteArr := [byte1, 0x7E, lengthBytes[1], lengthBytes[2]]
		
		} else if(this.length < 2 ^ 53) {
			lengthBytes := Uint64ToUChar(this.length)
			byteArr := [byte1, 0x7F, lengthBytes[1], lengthBytes[2], lengthBytes[3], lengthBytes[4]]
			
		}
		
		byteArr[2] |= 0x80 ; Set MASK bit

		length := this.length + byteArr.Length() + 4
		buf := new Buffer(length)

		VarSetCapacity(result, byteArr.Length())
		for i, byte in byteArr {
			NumPut(byte, result, A_Index - 1, "UInt")
		}
		buf.Write(&result, byteArr.Length())

		VarSetCapacity(TempMask, 4, 0)
		NumPut(TempMask, 0, "UInt")

		buf.Write(&TempMask, 4)
		buf.Write(this.pMessage, this.length)

		return buf
	}
	
}







class Event
{
    __new(ByRef emitter, ByRef data)
    {
        this.target := emitter
        this.data := data
        this.propagate := True
    }
    stopPropagation()
    {
        this.propagate := False
    }
}

class EventEmitter
{
    events := {}
    
    _addListener(eventName, ByRef listener, atStart := 0, once := 0)
    {
        if(!this.events[eventName])
        {
            this.events[eventName] := []
        }
        
        if(atStart)
        {
            this.events[eventName].InsertAt(1, {listener: listener, once: once})
        }
        else
        {
            this.events[eventName].Push({listener: listener, once: once})
        }
        return this
    }
    
    removeListener(event, ByRef listener)
    {
        if(this.events[event])
        {
            if(listener)
            {
                For i, eventListener in this.events[event]
                {
                    if(eventListener.listener == listener)
                    {
                        this.events[event].RemoveAt(i)
                    }
                }
            }
        }
        else
        {
            iListeners := this.events[eventName].Length()
            this.events[eventName].RemoveAt(1, iListeners-1)
        }
    }
    
    emit(eventName,ByRef data)
    {
        if(this.events[eventName])
        {
            iListeners := this.events[eventName].Length()
            if(iListeners)
            {
                e := new Event(this, data)
                For i, eventListener in this.events[eventName]
                {
                    
                    eventListener.listener.Call(e)
                    if(eventListener.once)
                    {
                        this.events[eventName].RemoveAt(i)
                    }
                    if(!e.propagate)
                    {
                        break
                    }
                }
            }
            return iListeners
        }
        return 0
    }
    
    
    prependOnceListener(event, ByRef listener)
    {
        return this._addListener(event, listener, 1, 1)
    }
    
    prependListener(event, ByRef listener)
    {
        return this._addListener(event, listener, 1, 0)
    }
    
    addListener(event, ByRef listener)
    {
        return this._addListener(event, listener, 0, 0)
    }
    
    once(event, ByRef listener)
    {
        return this._addListener(event, listener, 0, 1)
    }
    
    on(event, ByRef listener)
    {
        return this.addListener(event, listener)
    }
    
    off(event, ByRef listener)
    {
        this.removeListener(event, listener)
    }
}

sha1_encode(string, encoding := "utf-8") {
    static BCRYPT_SHA1_ALGORITHM := "SHA1"
    static BCRYPT_OBJECT_LENGTH  := "ObjectLength"
    static BCRYPT_HASH_LENGTH    := "HashDigestLength"
    
	try
	{
		; loads the specified module into the address space of the calling process
		if !(hBCRYPT := DllCall("LoadLibrary", "str", "bcrypt.dll", "ptr"))
        throw Exception("Failed to load bcrypt.dll", -1)
        
		; open an algorithm handle
		if (NT_STATUS := DllCall("bcrypt\BCryptOpenAlgorithmProvider", "ptr*", hAlg, "ptr", &BCRYPT_SHA1_ALGORITHM, "ptr", 0, "uint", 0) != 0)
        throw Exception("BCryptOpenAlgorithmProvider: " NT_STATUS, -1)
        
		; calculate the size of the buffer to hold the hash object
		if (NT_STATUS := DllCall("bcrypt\BCryptGetProperty", "ptr", hAlg, "ptr", &BCRYPT_OBJECT_LENGTH, "uint*", cbHashObject, "uint", 4, "uint*", cbData, "uint", 0) != 0)
        throw Exception("BCryptGetProperty: " NT_STATUS, -1)
        
		; allocate the hash object
		VarSetCapacity(pbHashObject, cbHashObject, 0)
		;	throw Exception("Memory allocation failed", -1)
        
		; calculate the length of the hash
		if (NT_STATUS := DllCall("bcrypt\BCryptGetProperty", "ptr", hAlg, "ptr", &BCRYPT_HASH_LENGTH, "uint*", cbHash, "uint", 4, "uint*", cbData, "uint", 0) != 0)
        throw Exception("BCryptGetProperty: " NT_STATUS, -1)
        
		; allocate the hash buffer
		VarSetCapacity(pbHash, cbHash, 0)
		;	throw Exception("Memory allocation failed", -1)
        
		; create a hash
		if (NT_STATUS := DllCall("bcrypt\BCryptCreateHash", "ptr", hAlg, "ptr*", hHash, "ptr", &pbHashObject, "uint", cbHashObject, "ptr", 0, "uint", 0, "uint", 0) != 0)
        throw Exception("BCryptCreateHash: " NT_STATUS, -1)
        
		; hash some data
		VarSetCapacity(pbInput, (StrPut(string, encoding) - 1) * ((encoding = "utf-16" || encoding = "cp1200") ? 2 : 1), 0) && cbInput := StrPut(string, &pbInput, encoding) - 1
		if (NT_STATUS := DllCall("bcrypt\BCryptHashData", "ptr", hHash, "ptr", &pbInput, "uint", cbInput, "uint", 0) != 0)
        throw Exception("BCryptHashData: " NT_STATUS, -1)
        
		; close the hash
		if (NT_STATUS := DllCall("bcrypt\BCryptFinishHash", "ptr", hHash, "ptr", &pbHash, "uint", cbHash, "uint", 0) != 0)
        throw Exception("BCryptFinishHash: " NT_STATUS, -1)
        
    }
	catch exception
	{
		; represents errors that occur during application execution
		throw Exception
    }
	finally
	{
		; cleaning up resources
		if (pbInput)
        VarSetCapacity(pbInput, 0)
		if (hHash)
        DllCall("bcrypt\BCryptDestroyHash", "ptr", hHash)
		;if (pbHash)
        ;	VarSetCapacity(pbHash, 0)
		if (pbHashObject)
        VarSetCapacity(pbHashObject, 0)
		if (hAlg)
        DllCall("bcrypt\BCryptCloseAlgorithmProvider", "ptr", hAlg, "uint", 0)
		if (hBCRYPT)
        DllCall("FreeLibrary", "ptr", hBCRYPT)
    }
    
	return [pbHash, cbHash]
}

Base64_encode(pData, Size) {
    if !DllCall("Crypt32\CryptBinaryToString"
    , "Ptr", pData       ; const BYTE *pbBinary
    , "UInt", Size     ; DWORD      cbBinary
    , "UInt", 0x40000001 ; DWORD      dwFlags = CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF
    , "Ptr", 0           ; LPWSTR     pszString
    , "UInt*", Base64Length    ; DWORD      *pcchString
    , "UInt") ; BOOL
    throw Exception("Failed to calculate b64 size")
    
    VarSetCapacity(Base64, Base64Length * (1 + A_IsUnicode), 0)
    
    if !DllCall("Crypt32\CryptBinaryToString"
    , "Ptr", pData       ; const BYTE *pbBinary
    , "UInt", Size     ; DWORD      cbBinary
    , "UInt", 0x40000001 ; DWORD      dwFlags = CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF
    , "Str", Base64         ; LPWSTR     pszString
    , "UInt*", Base64Length    ; DWORD      *pcchString
    , "UInt") ; BOOL
    throw Exception("Failed to convert to b64")
    
    return Base64
}

XOR(byteArr, keyArr)
{
    keylen := keyArr.length()
    decodedArr := []
    for i, byte in byteArr{
        key :=  keyArr[mod(A_Index - 1, keylen) + 1]
        decodedByte := byte ^ key
        decodedArr.push(decodedByte)
    }
    return decodedArr
}


class Uri
{
    Decode(str) {
        Loop
            If RegExMatch(str, "i)(?<=%)[\da-f]{1,2}", hex)
                StringReplace, str, str, `%%hex%, % Chr("0x" . hex), All
            Else Break
        Return, str
    }

    Encode(str) {
        f = %A_FormatInteger%
        SetFormat, Integer, Hex
        If RegExMatch(str, "^\w+:/{0,2}", pr)
            StringTrimLeft, str, str, StrLen(pr)
        StringReplace, str, str, `%, `%25, All
        Loop
            If RegExMatch(str, "i)[^\w\.~%]", char)
                StringReplace, str, str, %char%, % "%" . Asc(char), All
            Else Break
        SetFormat, Integer, %f%
        Return, pr . str
    }
}

class Buffer
{
    __New(len) {
        this.SetCapacity("buffer", len)
        this.length := len
        this.index := 0
    }

    FromString(str, encoding = "UTF-8") {
        length := Buffer.GetStrSize(str, encoding)
        buffer := new Buffer(length)
        buffer.WriteStr(str)
        return buffer
    }

    GetStrSize(str, encoding = "UTF-8") {
        encodingSize := ((encoding="utf-16" || encoding="cp1200") ? 2 : 1)
        ; length of string, minus null char
        return StrPut(str, encoding) - encodingSize
    }

    WriteStr(str, encoding := "UTF-8") {
        length := this.GetStrSize(str, encoding)
        
        VarSetCapacity(text, length)
        StrPut(str, &text, encoding)

        this.Write(&text, length)
        return length
    }

    ; data is a pointer to the data
    Write(data, length) {
        if (this.index + length > this.length) {
            this.SetCapacity("buffer", this.index + length)
        }

        p := this.GetPointer()
        DllCall("RtlMoveMemory", "ptr", p + this.index, "ptr", data, "uint", length)
        this.index += length
    }

    Append(ByRef buffer) {
        destP := this.GetPointer()
        sourceP := buffer.GetPointer()

        DllCall("RtlMoveMemory", "ptr", destP + this.length, "ptr", sourceP, "uint", buffer.length)
        this.length += buffer.length
    }

    GetPointer() {
        return this.GetAddress("buffer")
    }

    Done() {
        this.SetCapacity("buffer", this.length)
    }
}

class Socket
{
	static WM_SOCKET := 0x9987, MSG_PEEK := 2
	static FD_READ := 1, FD_ACCEPT := 8, FD_CLOSE := 32
	static Blocking := True, BlockSleep := 50
	
	__New(Socket:=-1)
	{
		static Init
		if (!Init)
		{
			DllCall("LoadLibrary", "Str", "Ws2_32", "Ptr")
			VarSetCapacity(WSAData, 394+A_PtrSize)
			if (Error := DllCall("Ws2_32\WSAStartup", "UShort", 0x0202, "Ptr", &WSAData))
				throw Exception("Error starting Winsock",, Error)
			if (NumGet(WSAData, 2, "UShort") != 0x0202)
				throw Exception("Winsock version 2.2 not available")
			Init := True
		}
		this.Socket := Socket
	}
	
	__Delete()
	{
		if (this.Socket != -1)
			this.Disconnect()
	}
	
	Connect(Address)
	{
		if (this.Socket != -1)
			throw Exception("Socket already connected")
		Next := pAddrInfo := this.GetAddrInfo(Address)
		while Next
		{
			ai_addrlen := NumGet(Next+0, 16, "UPtr")
			ai_addr := NumGet(Next+0, 16+(2*A_PtrSize), "Ptr")
			if ((this.Socket := DllCall("Ws2_32\socket", "Int", NumGet(Next+0, 4, "Int")
				, "Int", this.SocketType, "Int", this.ProtocolId, "UInt")) != -1)
			{
				if (DllCall("Ws2_32\WSAConnect", "UInt", this.Socket, "Ptr", ai_addr
					, "UInt", ai_addrlen, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Int") == 0)
				{
					DllCall("Ws2_32\freeaddrinfo", "Ptr", pAddrInfo) ; TODO: Error Handling
					return this.EventProcRegister(this.FD_READ | this.FD_CLOSE)
				}
				this.Disconnect()
			}
			Next := NumGet(Next+0, 16+(3*A_PtrSize), "Ptr")
		}
		throw Exception("Error connecting")
	}
	
	Bind(Address)
	{
		if (this.Socket != -1)
			throw Exception("Socket already connected")
		Next := pAddrInfo := this.GetAddrInfo(Address)
		while Next
		{
			ai_addrlen := NumGet(Next+0, 16, "UPtr")
			ai_addr := NumGet(Next+0, 16+(2*A_PtrSize), "Ptr")
			if ((this.Socket := DllCall("Ws2_32\socket", "Int", NumGet(Next+0, 4, "Int")
				, "Int", this.SocketType, "Int", this.ProtocolId, "UInt")) != -1)
			{
				if (DllCall("Ws2_32\bind", "UInt", this.Socket, "Ptr", ai_addr
					, "UInt", ai_addrlen, "Int") == 0)
				{
					DllCall("Ws2_32\freeaddrinfo", "Ptr", pAddrInfo) ; TODO: ERROR HANDLING
					return this.EventProcRegister(this.FD_READ | this.FD_ACCEPT | this.FD_CLOSE)
				}
				this.Disconnect()
			}
			Next := NumGet(Next+0, 16+(3*A_PtrSize), "Ptr")
		}
		throw Exception("Error binding")
	}
	
	Listen(backlog=32)
	{
		return DllCall("Ws2_32\listen", "UInt", this.Socket, "Int", backlog) == 0
	}
	
	Accept()
	{
		if ((s := DllCall("Ws2_32\accept", "UInt", this.Socket, "Ptr", 0, "Ptr", 0, "Ptr")) == -1)
			throw Exception("Error calling accept",, this.GetLastError())
		Sock := new Socket(s)
		Sock.ProtocolId := this.ProtocolId
		Sock.SocketType := this.SocketType
		Sock.EventProcRegister(this.FD_READ | this.FD_CLOSE)
		return Sock
	}
	
	Disconnect()
	{
		; Return 0 if not connected
		if (this.Socket == -1)
			return 0
		
		; Unregister the socket event handler and close the socket
		this.EventProcUnregister()
		if (DllCall("Ws2_32\closesocket", "UInt", this.Socket, "Int") == -1)
			throw Exception("Error closing socket",, this.GetLastError())
		this.Socket := -1
		return 1
	}
	
	MsgSize()
	{
		static FIONREAD := 0x4004667F
		if (DllCall("Ws2_32\ioctlsocket", "UInt", this.Socket, "UInt", FIONREAD, "UInt*", argp) == -1)
			throw Exception("Error calling ioctlsocket",, this.GetLastError())
		return argp
	}
	
	Send(pBuffer, BufSize, Flags:=0)
	{
		if ((r := DllCall("Ws2_32\send", "UInt", this.Socket, "Ptr", pBuffer, "Int", BufSize, "Int", Flags)) == -1)
			throw Exception("Error calling send",, this.GetLastError())
		return r
	}
	
	SendText(Text, Flags:=0, Encoding:="UTF-8")
	{
		local

		VarSetCapacity(Buffer, StrPut(Text, Encoding) * ((Encoding="UTF-16"||Encoding="cp1200") ? 2 : 1))
		Length := StrPut(Text, &Buffer, Encoding)
		return this.Send(&Buffer, Length - 1)
	}
	
	Recv(ByRef Buffer, BufSize:=0, Flags:=0)
	{
		local

		while (!(Length := this.MsgSize()) && this.Blocking)
			Sleep, this.BlockSleep
		if !Length
			return 0
		if !BufSize
			BufSize := Length
		VarSetCapacity(Buffer, BufSize)
		if ((r := DllCall("Ws2_32\recv", "UInt", this.Socket, "Ptr", &Buffer, "Int", BufSize, "Int", Flags)) == -1)
			throw Exception("Error calling recv",, this.GetLastError())
		return r
	}
	
	RecvText(BufSize:=0, Flags:=0, Encoding:="UTF-8")
	{
		local

		if (Length := this.Recv(Buffer, BufSize, flags))
			return StrGet(&Buffer, Length, Encoding)
		return ""
	}
	
	RecvLine(BufSize:=0, Flags:=0, Encoding:="UTF-8", KeepEnd:=False)
	{
		while !(i := InStr(this.RecvText(BufSize, Flags|this.MSG_PEEK, Encoding), "`n"))
		{
			if !this.Blocking
				return ""
			Sleep, this.BlockSleep
		}
		if KeepEnd
			return this.RecvText(i, Flags, Encoding)
		else
			return RTrim(this.RecvText(i, Flags, Encoding), "`r`n")
	}
	
	GetAddrInfo(Address)
	{
		; TODO: Use GetAddrInfoW
		Host := Address[1], Port := Address[2]
		VarSetCapacity(Hints, 16+(4*A_PtrSize), 0)
		NumPut(this.SocketType, Hints, 8, "Int")
		NumPut(this.ProtocolId, Hints, 12, "Int")
		if (Error := DllCall("Ws2_32\getaddrinfo", "AStr", Host, "AStr", Port, "Ptr", &Hints, "Ptr*", Result))
			throw Exception("Error calling GetAddrInfo",, Error)
		return Result
	}
	
	OnMessage(wParam, lParam, Msg, hWnd)
	{
		Critical
		if (Msg != this.WM_SOCKET || wParam != this.Socket)
			return
		if (lParam & this.FD_READ)
			this.onRecv()
		else if (lParam & this.FD_ACCEPT)
			this.onAccept()
		else if (lParam & this.FD_CLOSE)
			this.EventProcUnregister(), this.OnDisconnect()
	}
	
	EventProcRegister(lEvent)
	{
		this.AsyncSelect(lEvent)
		if !this.Bound
		{
			this.Bound := this.OnMessage.Bind(this)
			OnMessage(this.WM_SOCKET, this.Bound)
		}
	}
	
	EventProcUnregister()
	{
		this.AsyncSelect(0)
		if this.Bound
		{
			OnMessage(this.WM_SOCKET, this.Bound, 0)
			this.Bound := False
		}
	}
	
	AsyncSelect(lEvent)
	{
		if (DllCall("Ws2_32\WSAAsyncSelect"
			, "UInt", this.Socket    ; s
			, "Ptr", A_ScriptHwnd    ; hWnd
			, "UInt", this.WM_SOCKET ; wMsg
			, "UInt", lEvent) == -1) ; lEvent
			throw Exception("Error calling WSAAsyncSelect",, this.GetLastError())
	}
	
	GetLastError()
	{
		return DllCall("Ws2_32\WSAGetLastError")
	}
}

class SocketTCP extends Socket
{
	static ProtocolId := 6 ; IPPROTO_TCP
	static SocketType := 1 ; SOCK_STREAM
}

class SocketUDP extends Socket
{
	static ProtocolId := 17 ; IPPROTO_UDP
	static SocketType := 2  ; SOCK_DGRAM
	
	SetBroadcast(Enable)
	{
		static SOL_SOCKET := 0xFFFF, SO_BROADCAST := 0x20
		if (DllCall("Ws2_32\setsockopt"
			, "UInt", this.Socket ; SOCKET s
			, "Int", SOL_SOCKET   ; int    level
			, "Int", SO_BROADCAST ; int    optname
			, "UInt*", !!Enable   ; *char  optval
			, "Int", 4) == -1)    ; int    optlen
			throw Exception("Error calling setsockopt",, this.GetLastError())
	}
}



/*
	; AHK v1.1
	
*/

class CConsole
{
    ahkPID  :=
    ahkHWND :=

	__New( title := "Console" ) {
		HWND := WinExist( %title% " ahk_class Notepad" )
		if ( HWND ) {
			WinGet, PID, PID, % "ahk_id " HWND
			this.ahkPID  := "ahk_pid " PID
			this.ahkHWND := "ahk_id " HWND
			this.clear()
		} else {
			DetectHiddenWindows, On
			Run, Notepad,, Hide, PID
			this.ahkPID := "ahk_pid " PID
			WinWait, % this.ahkPID
			HWND := WinExist( this.ahkPID )
			if HWND=0
				return
			this.ahkHWND := "ahk_id " HWND
			WinMove, % this.ahkHWND,, 0, 0, % A_ScreenWidth/4, % A_ScreenHeight
			WinSetTitle, % this.ahkHWND,, %title%
			;WinActivate, % this.ahkHWND
			WinShow, % this.ahkHWND
		}
    }

	hotkey{
		set {
			show_bind := ObjBindMethod( this, "show" )
			Hotkey, % value, % show_bind
		}
	}

	log( texts* ) {
		if ( !WinExist( this.ahkHWND ) )
			return
		last := texts.Length()
		if last == 0
			Control, EditPaste, % "`r`n", Edit1, % this.ahkHWND
		for index, txt in texts {
			if (IsObject(txt)) {
				Control, EditPaste, % "{`r`n", Edit1, % this.ahkHWND
				for key, value in txt {
					Control, EditPaste, % "`t" key ": " value "`r`n", Edit1, % this.ahkHWND
				}
				Control, EditPaste, % "}`r`n", Edit1, % this.ahkHWND
			} else {
				sep := (index=last? "`r`n" : " ")
				Control, EditPaste, % StrReplace(StrReplace(txt sep,",","`n`t,"),"}","`n}"), Edit1, % this.ahkHWND  ; ControlSendText ? ControlEditPaste
			}
		}
	}

	show() {
		WinSet, AlwaysOnTop, % true, % this.ahkHWND
		WinSet, AlwaysOnTop, % false, % this.ahkHWND
	}

	clear() {
		ControlSetText, Edit1,, % this.ahkHWND
	}

}


;tsk-json.ahk



/**
 * Lib: JSON.ahk
 *     JSON lib for AutoHotkey.
 * Version:
 *     v2.1.3 [updated 04/18/2016 (MM/DD/YYYY)]
 * License:
 *     WTFPL [http://wtfpl.net/]
 * Requirements:
 *     Latest version of AutoHotkey (v1.1+ or v2.0-a+)
 * Installation:
 *     Use #Include JSON.ahk or copy into a function library folder and then
 *     use #Include <JSON>
 * Links:
 *     GitHub:     - https://github.com/cocobelgica/AutoHotkey-JSON
 *     Forum Topic - http://goo.gl/r0zI8t
 *     Email:      - cocobelgica <at> gmail <dot> com
 */
/**
 * Class: JSON
 *     The JSON object contains methods for parsing JSON and converting values
 *     to JSON. Callable - NO; Instantiable - YES; Subclassable - YES;
 *     Nestable(via #Include) - NO.
 * Methods:
 *     Load() - see relevant documentation before method definition header
 *     Dump() - see relevant documentation before method definition header
 */
class JSON
{
	/**
	 * Method: Load
	 *     Parses a JSON string into an AHK value
	 * Syntax:
	 *     value := JSON.Load( text [, reviver ] )
	 * Parameter(s):
	 *     value      [retval] - parsed value
	 *     text    [in, ByRef] - JSON formatted string
	 *     reviver   [in, opt] - function object, similar to JavaScript's
	 *                           JSON.parse() 'reviver' parameter
	 */
	class Load extends JSON.Functor
	{
		Call(self, ByRef text, reviver:="")
		{
			this.rev := IsObject(reviver) ? reviver : false
		; Object keys(and array indices) are temporarily stored in arrays so that
		; we can enumerate them in the order they appear in the document/text instead
		; of alphabetically. Skip if no reviver function is specified.
			this.keys := this.rev ? {} : false
			static quot := Chr(34), bashq := "\" . quot
			     , json_value := quot . "{[01234567890-tfn"
			     , json_value_or_array_closing := quot . "{[]01234567890-tfn"
			     , object_key_or_object_closing := quot . "}"
			key := ""
			is_key := false
			root := {}
			stack := [root]
			next := json_value
			pos := 0
			while ((ch := SubStr(text, ++pos, 1)) != "") {
				if InStr(" `t`r`n", ch)
					continue
				if !InStr(next, ch, 1)
					this.ParseError(next, text, pos)
				holder := stack[1]
				is_array := holder.IsArray
				if InStr(",:", ch) {
					next := (is_key := !is_array && ch == ",") ? quot : json_value
				} else if InStr("}]", ch) {
					ObjRemoveAt(stack, 1)
					next := stack[1]==root ? "" : stack[1].IsArray ? ",]" : ",}"
				} else {
					if InStr("{[", ch) {
					; Check if Array() is overridden and if its return value has
					; the 'IsArray' property. If so, Array() will be called normally,
					; otherwise, use a custom base object for arrays
						static json_array := Func("Array").IsBuiltIn || ![].IsArray ? {IsArray: true} : 0
					
					; sacrifice readability for minor(actually negligible) performance gain
						(ch == "{")
							? ( is_key := true
							  , value := {}
							  , next := object_key_or_object_closing )
						; ch == "["
							: ( value := json_array ? new json_array : []
							  , next := json_value_or_array_closing )
						
						ObjInsertAt(stack, 1, value)
						if (this.keys)
							this.keys[value] := []
					
					} else {
						if (ch == quot) {
							i := pos
							while (i := InStr(text, quot,, i+1)) {
								value := StrReplace(SubStr(text, pos+1, i-pos-1), "\\", "\u005c")
								static tail := A_AhkVersion<"2" ? 0 : -1
								if (SubStr(value, tail) != "\")
									break
							}
							if (!i)
								this.ParseError("'", text, pos)
							  value := StrReplace(value,  "\/",  "/")
							, value := StrReplace(value, bashq, quot)
							, value := StrReplace(value,  "\b", "`b")
							, value := StrReplace(value,  "\f", "`f")
							, value := StrReplace(value,  "\n", "`n")
							, value := StrReplace(value,  "\r", "`r")
							, value := StrReplace(value,  "\t", "`t")
							pos := i ; update pos
							
							i := 0
							while (i := InStr(value, "\",, i+1)) {
								if !(SubStr(value, i+1, 1) == "u")
									this.ParseError("\", text, pos - StrLen(SubStr(value, i+1)))
								uffff := Abs("0x" . SubStr(value, i+2, 4))
								if (A_IsUnicode || uffff < 0x100)
									value := SubStr(value, 1, i-1) . Chr(uffff) . SubStr(value, i+6)
							}
							if (is_key) {
								key := value, next := ":"
								continue
							}
						
						} else {
							value := SubStr(text, pos, i := RegExMatch(text, "[\]\},\s]|$",, pos)-pos)
							static number := "number", integer :="integer"
							if value is %number%
							{
								if value is %integer%
									value += 0
							}
							else if (value == "true" || value == "false")
								value := %value% + 0
							else if (value == "null")
								value := ""
							else
							; we can do more here to pinpoint the actual culprit
							; but that's just too much extra work.
								this.ParseError(next, text, pos, i)
							pos += i-1
						}
						next := holder==root ? "" : is_array ? ",]" : ",}"
					} ; If InStr("{[", ch) { ... } else
					is_array? key := ObjPush(holder, value) : holder[key] := value
					if (this.keys && this.keys.HasKey(holder))
						this.keys[holder].Push(key)
				}
			
			} ; while ( ... )
			return this.rev ? this.Walk(root, "") : root[""]
		}
		ParseError(expect, ByRef text, pos, len:=1)
		{
			static quot := Chr(34), qurly := quot . "}"
			
			line := StrSplit(SubStr(text, 1, pos), "`n", "`r").Length()
			col := pos - InStr(text, "`n",, -(StrLen(text)-pos+1))
			msg := Format("{1}`n`nLine:`t{2}`nCol:`t{3}`nChar:`t{4}"
			,     (expect == "")     ? "Extra data"
			    : (expect == "'")    ? "Unterminated string starting at"
			    : (expect == "\")    ? "Invalid \escape"
			    : (expect == ":")    ? "Expecting ':' delimiter"
			    : (expect == quot)   ? "Expecting object key enclosed in double quotes"
			    : (expect == qurly)  ? "Expecting object key enclosed in double quotes or object closing '}'"
			    : (expect == ",}")   ? "Expecting ',' delimiter or object closing '}'"
			    : (expect == ",]")   ? "Expecting ',' delimiter or array closing ']'"
			    : InStr(expect, "]") ? "Expecting JSON value or array closing ']'"
			    :                      "Expecting JSON value(string, number, true, false, null, object or array)"
			, line, col, pos)
			static offset := A_AhkVersion<"2" ? -3 : -4
			throw Exception(msg, offset, SubStr(text, pos, len))
		}
		Walk(holder, key)
		{
			value := holder[key]
			if IsObject(value) {
				for i, k in this.keys[value] {
					; check if ObjHasKey(value, k) ??
					v := this.Walk(value, k)
					if (v != JSON.Undefined)
						value[k] := v
					else
						ObjDelete(value, k)
				}
			}
			
			return this.rev.Call(holder, key, value)
		}
	}
	/**
	 * Method: Dump
	 *     Converts an AHK value into a JSON string
	 * Syntax:
	 *     str := JSON.Dump( value [, replacer, space ] )
	 * Parameter(s):
	 *     str        [retval] - JSON representation of an AHK value
	 *     value          [in] - any value(object, string, number)
	 *     replacer  [in, opt] - function object, similar to JavaScript's
	 *                           JSON.stringify() 'replacer' parameter
	 *     space     [in, opt] - similar to JavaScript's JSON.stringify()
	 *                           'space' parameter
	 */
	class Dump extends JSON.Functor
	{
		Call(self, value, replacer:="", space:="")
		{
			this.rep := IsObject(replacer) ? replacer : ""
			this.gap := ""
			if (space) {
				static integer := "integer"
				if space is %integer%
					Loop, % ((n := Abs(space))>10 ? 10 : n)
						this.gap .= " "
				else
					this.gap := SubStr(space, 1, 10)
				this.indent := "`n"
			}
			return this.Str({"": value}, "")
		}
		Str(holder, key)
		{
			value := holder[key]
			if (this.rep)
				value := this.rep.Call(holder, key, ObjHasKey(holder, key) ? value : JSON.Undefined)
			if IsObject(value) {
			; Check object type, skip serialization for other object types such as
			; ComObject, Func, BoundFunc, FileObject, RegExMatchObject, Property, etc.
				static type := A_AhkVersion<"2" ? "" : Func("Type")
				if (type ? type.Call(value) == "Object" : ObjGetCapacity(value) != "") {
					if (this.gap) {
						stepback := this.indent
						this.indent .= this.gap
					}
					is_array := value.IsArray
				; Array() is not overridden, rollback to old method of
				; identifying array-like objects. Due to the use of a for-loop
				; sparse arrays such as '[1,,3]' are detected as objects({}). 
					if (!is_array) {
						for i in value
							is_array := i == A_Index
						until !is_array
					}
					str := ""
					if (is_array) {
						Loop, % value.Length() {
							if (this.gap)
								str .= this.indent
							
							v := this.Str(value, A_Index)
							str .= (v != "") ? v . "," : "null,"
						}
					} else {
						colon := this.gap ? ": " : ":"
						for k in value {
							v := this.Str(value, k)
							if (v != "") {
								if (this.gap)
									str .= this.indent
								str .= this.Quote(k) . colon . v . ","
							}
						}
					}
					if (str != "") {
						str := RTrim(str, ",")
						if (this.gap)
							str .= stepback
					}
					if (this.gap)
						this.indent := stepback
					return is_array ? "[" . str . "]" : "{" . str . "}"
				}
			
			} else ; is_number ? value : "value"
				return ObjGetCapacity([value], 1)=="" ? value : this.Quote(value)
		}
		Quote(string)
		{
			static quot := Chr(34), bashq := "\" . quot
			if (string != "") {
				  string := StrReplace(string,  "\",  "\\")
				; , string := StrReplace(string,  "/",  "\/") ; optional in ECMAScript
				, string := StrReplace(string, quot, bashq)
				, string := StrReplace(string, "`b",  "\b")
				, string := StrReplace(string, "`f",  "\f")
				, string := StrReplace(string, "`n",  "\n")
				, string := StrReplace(string, "`r",  "\r")
				, string := StrReplace(string, "`t",  "\t")
				static rx_escapable := A_AhkVersion<"2" ? "O)[^\x20-\x7e]" : "[^\x20-\x7e]"
				while RegExMatch(string, rx_escapable, m)
					string := StrReplace(string, m.Value, Format("\u{1:04x}", Ord(m.Value)))
			}
			return quot . string . quot
		}
	}
	/**
	 * Property: Undefined
	 *     Proxy for 'undefined' type
	 * Syntax:
	 *     undefined := JSON.Undefined
	 * Remarks:
	 *     For use with reviver and replacer functions since AutoHotkey does not
	 *     have an 'undefined' type. Returning blank("") or 0 won't work since these
	 *     can't be distnguished from actual JSON values. This leaves us with objects.
	 *     Replacer() - the caller may return a non-serializable AHK objects such as
	 *     ComObject, Func, BoundFunc, FileObject, RegExMatchObject, and Property to
	 *     mimic the behavior of returning 'undefined' in JavaScript but for the sake
	 *     of code readability and convenience, it's better to do 'return JSON.Undefined'.
	 *     Internally, the property returns a ComObject with the variant type of VT_EMPTY.
	 */
	Undefined[]
	{
		get {
			static empty := {}, vt_empty := ComObject(0, &empty, 1)
			return vt_empty
		}
	}
	class Functor
	{
		__Call(method, ByRef arg, args*)
		{
		; When casting to Call(), use a new instance of the "function object"
		; so as to avoid directly storing the properties(used across sub-methods)
		; into the "function object" itself.
			if IsObject(method)
				return (new this).Call(method, arg, args*)
			else if (method == "")
				return (new this).Call(arg, args*)
		}
	}
}




;array_gui

Array_Gui(Array, Parent="") {
	if !Parent
	{
		Gui, +HwndDefault
		Gui, New, +HwndGuiArray +LabelGuiArray +Resize
		Gui, Margin, 5, 5
		Gui, Add, TreeView, w300 h200
		
		Item := TV_Add("Array", 0, "+Expand")
		Array_Gui(Array, Item)
		
		Gui, Show,, GuiArray
		Gui, %Default%:Default
		
		WinWait, ahk_id%GuiArray%
		WinWaitClose, ahk_id%GuiArray%
		return
	}
	
	For Key, Value in Array
	{
		Item := TV_Add(Key, Parent)
		if (IsObject(Value))
			Array_Gui(Value, Item)
		else
			TV_Add(Value, Item)
	}
	return
	
	GuiArrayClose:
	Gui, Destroy
	return
	
	GuiArraySize:
	GuiControl, Move, SysTreeView321, % "w" A_GuiWidth - 10 " h" A_GuiHeight - 10
	return
}

















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
            
            this.Disconnect(A_thisFunc)
            this.console.__Delete() 
        }
        kill()
        {
           
                    this.killed := true
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
            ;this.kill()
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
                if !(this.connected){
					msgbox % "disconnected"
					return "disconnected"
				}
                    
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
				if (this.killed){
					return
				}
				;msgbox % "DIS"
				session := {"error":"Inspector.detached"}
				stdout := FileOpen("*", "w `n")
				stdout.WriteLine(JSON.DUMP(session))    

				exitapp  
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










Jxon_Load(ByRef src, args*)
{
	static q := Chr(34)

	key := "", is_key := false
	stack := [ tree := [] ]
	is_arr := { (tree): 1 }
	next := q . "{[01234567890-tfn"
	pos := 0
	while ( (ch := SubStr(src, ++pos, 1)) != "" )
	{
		if InStr(" `t`n`r", ch)
			continue
		if !InStr(next, ch, true)
		{
			ln := ObjLength(StrSplit(SubStr(src, 1, pos), "`n"))
			col := pos - InStr(src, "`n",, -(StrLen(src)-pos+1))

			msg := Format("{}: line {} col {} (char {})"
			,   (next == "")      ? ["Extra data", ch := SubStr(src, pos)][1]
			  : (next == "'")     ? "Unterminated string starting at"
			  : (next == "\")     ? "Invalid \escape"
			  : (next == ":")     ? "Expecting ':' delimiter"
			  : (next == q)       ? "Expecting object key enclosed in double quotes"
			  : (next == q . "}") ? "Expecting object key enclosed in double quotes or object closing '}'"
			  : (next == ",}")    ? "Expecting ',' delimiter or object closing '}'"
			  : (next == ",]")    ? "Expecting ',' delimiter or array closing ']'"
			  : [ "Expecting JSON value(string, number, [true, false, null], object or array)"
			    , ch := SubStr(src, pos, (SubStr(src, pos)~="[\]\},\s]|$")-1) ][1]
			, ln, col, pos)

			throw Exception(msg, -1, ch)
		}

		is_array := is_arr[obj := stack[1]]

		if i := InStr("{[", ch)
		{
			val := (proto := args[i]) ? new proto : {}
			is_array? ObjPush(obj, val) : obj[key] := val
			ObjInsertAt(stack, 1, val)
			
			is_arr[val] := !(is_key := ch == "{")
			next := q . (is_key ? "}" : "{[]0123456789-tfn")
		}

		else if InStr("}]", ch)
		{
			ObjRemoveAt(stack, 1)
			next := stack[1]==tree ? "" : is_arr[stack[1]] ? ",]" : ",}"
		}

		else if InStr(",:", ch)
		{
			is_key := (!is_array && ch == ",")
			next := is_key ? q : q . "{[0123456789-tfn"
		}

		else ; string | number | true | false | null
		{
			if (ch == q) ; string
			{
				i := pos
				while i := InStr(src, q,, i+1)
				{
					val := StrReplace(SubStr(src, pos+1, i-pos-1), "\\", "\u005C")
					static end := A_AhkVersion<"2" ? 0 : -1
					if (SubStr(val, end) != "\")
						break
				}
				if !i ? (pos--, next := "'") : 0
					continue

				pos := i ; update pos

				  val := StrReplace(val,    "\/",  "/")
				, val := StrReplace(val, "\" . q,    q)
				, val := StrReplace(val,    "\b", "`b")
				, val := StrReplace(val,    "\f", "`f")
				, val := StrReplace(val,    "\n", "`n")
				, val := StrReplace(val,    "\r", "`r")
				, val := StrReplace(val,    "\t", "`t")

				i := 0
				while i := InStr(val, "\",, i+1)
				{
					if (SubStr(val, i+1, 1) != "u") ? (pos -= StrLen(SubStr(val, i)), next := "\") : 0
						continue 2

					; \uXXXX - JSON unicode escape sequence
					xxxx := Abs("0x" . SubStr(val, i+2, 4))
					if (A_IsUnicode || xxxx < 0x100)
						val := SubStr(val, 1, i-1) . Chr(xxxx) . SubStr(val, i+6)
				}

				if is_key
				{
					key := val, next := ":"
					continue
				}
			}

			else ; number | true | false | null
			{
				val := SubStr(src, pos, i := RegExMatch(src, "[\]\},\s]|$",, pos)-pos)
			
			; For numerical values, numerify integers and keep floats as is.
			; I'm not yet sure if I should numerify floats in v2.0-a ...
				static number := "number", integer := "integer"
				if val is %number%
				{
					if val is %integer%
						val += 0
				}
			; in v1.1, true,false,A_PtrSize,A_IsUnicode,A_Index,A_EventInfo,
			; SOMETIMES return strings due to certain optimizations. Since it
			; is just 'SOMETIMES', numerify to be consistent w/ v2.0-a
				else if (val == "true" || val == "false")
					val := %val% + 0
			; AHK_H has built-in null, can't do 'val := %value%' where value == "null"
			; as it would raise an exception in AHK_H(overriding built-in var)
				else if (val == "null")
					val := ""
			; any other values are invalid, continue to trigger error
				else if (pos--, next := "#")
					continue
				
				pos += i-1
			}
			
			is_array? ObjPush(obj, val) : obj[key] := val
			next := obj==tree ? "" : is_array ? ",]" : ",}"
		}
	}

	return tree[1]
}

Jxon_Dump(obj, indent:="", lvl:=1)
{
	static q := Chr(34)

	if IsObject(obj)
	{
		static Type := Func("Type")
		if Type ? (Type.Call(obj) != "Object") : (ObjGetCapacity(obj) == "")
			throw Exception("Object type not supported.", -1, Format("<Object at 0x{:p}>", &obj))

		is_array := 0
		for k in obj
			is_array := k == A_Index
		until !is_array

		static integer := "integer"
		if indent is %integer%
		{
			if (indent < 0)
				throw Exception("Indent parameter must be a postive integer.", -1, indent)
			spaces := indent, indent := ""
			Loop % spaces
				indent .= " "
		}
		indt := ""
		Loop, % indent ? lvl : 0
			indt .= indent

		lvl += 1, out := "" ; Make #Warn happy
		for k, v in obj
		{
			if IsObject(k) || (k == "")
				throw Exception("Invalid object key.", -1, k ? Format("<Object at 0x{:p}>", &obj) : "<blank>")
			
			if !is_array
				out .= ( ObjGetCapacity([k], 1) ? Jxon_Dump(k) : q . k . q ) ;// key
				    .  ( indent ? ": " : ":" ) ; token + padding
			out .= Jxon_Dump(v, indent, lvl) ; value
			    .  ( indent ? ",`n" . indt : "," ) ; token + indent
		}

		if (out != "")
		{
			out := Trim(out, ",`n" . indent)
			if (indent != "")
				out := "`n" . indt . out . "`n" . SubStr(indt, StrLen(indent)+1)
		}
		
		return is_array ? "[" . out . "]" : "{" . out . "}"
	}

	; Number
	else if (ObjGetCapacity([obj], 1) == "")
		return obj

	; String (null -> not supported by AHK)
	if (obj != "")
	{
		  obj := StrReplace(obj,  "\",    "\\")
		, obj := StrReplace(obj,  "/",    "\/")
		, obj := StrReplace(obj,    q, "\" . q)
		, obj := StrReplace(obj, "`b",    "\b")
		, obj := StrReplace(obj, "`f",    "\f")
		, obj := StrReplace(obj, "`n",    "\n")
		, obj := StrReplace(obj, "`r",    "\r")
		, obj := StrReplace(obj, "`t",    "\t")

		static needle := (A_AhkVersion<"2" ? "O)" : "") . "[^\x20-\x7e]"
		while RegExMatch(obj, needle, m)
			obj := StrReplace(obj, m[0], Format("\u{:04X}", Ord(m[0])))
	}
	
	return q . obj . q
}

Jxon_True()
{
	static obj := {}
	return obj
}

Jxon_False()
{
	static obj := {}
	return obj
}