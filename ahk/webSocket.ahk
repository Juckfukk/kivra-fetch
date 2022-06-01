






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