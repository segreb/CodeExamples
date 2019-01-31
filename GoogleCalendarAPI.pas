unit GoogleCalendarAPI;

interface
uses
  Classes, ThreadedGetCalendars, uDB, SuperObject;

function GetPrimaryAccessToken(Adm: TdbmDental): boolean;

function GetLastErrorGoogleCalendar: string;
procedure SetLastErrorGoogleCalendar(AErrorMessage: string);

function GetCalendarList(var jsonList: widestring): boolean; overload;
function GetCalendarList(var jsonList: widestring; var NeedNewToken: boolean): boolean; overload;

function GetCalendarItems(Adm: TdbmDental; ACalendarID: widestring; var jsonList: widestring): boolean; overload;
function GetCalendarItems(Adm: TdbmDental; ACalendarID: widestring; var jsonList: widestring; var NeedNewToken: boolean): boolean; overload;

function DeleteEvent(Adm: TdbmDental; ACalendarID, AEventID: widestring): boolean; overload;
function DeleteEvent(Adm: TdbmDental; ACalendarID, AEventID: widestring; var NeedNewToken: boolean): boolean; overload;

function AddUpdateEvent(Adm: TdbmDental; AHttpMethod, AMethodURL: string; AEvent: ISuperObject): boolean; overload;
function AddUpdateEvent(Adm: TdbmDental; AHttpMethod, AMethodURL: string; AEvent: ISuperObject; var NeedNewToken: boolean): boolean; overload;

function LocalTimeToRTF3339(ADateTime: TDateTime): string;
function RealBias: integer;

//function CreateDraft(Receiver: string; Subject: string; Attachments: TStringList): boolean; overload;

implementation
uses
  WinInet, JvStrings, pFIBDataSet, pFIBDataBase, SysUtils, Windows,
  uCommonDefinitions, PFIBProps, DentalDateUtils, Forms;

type
  PErrorItem = ^TErrorItem;
  TErrorItem = record
    ThreadID: Cardinal;
    ErrorTime: TDateTime;
    ErrorMessage: string;
  end;
  TErrorsList = class(TList)
  protected
    procedure Notify(Ptr: Pointer; Action: TListNotification); virtual;
  end;

var
  ErrorsSync: TMultiReadExclusiveWriteSynchronizer;
  ErrorsList: TErrorsList;

procedure SetLastErrorGoogleCalendar(AErrorMessage: string);
var
  i, n: integer;
  ErrorItem: PErrorItem;
begin
  ErrorsSync.BeginWrite;
  try
    //Чистим те, которые в списке более часа
    for i:=ErrorsList.Count-1 downto 0 do begin
      if (PErrorItem(ErrorsList.Items[i])^.ErrorTime + 1/24) < Now() then begin
        ErrorsList.Delete(i);
      end;
    end;

    n := -1;
    for i:=0 to ErrorsList.Count-1 do
      if PErrorItem(ErrorsList.Items[i])^.ThreadID = GetCurrentThreadId then begin
        n := i;
        Break;
      end;
    if n=-1 then begin
      New(ErrorItem);
      ErrorItem^.ThreadID := GetCurrentThreadId;
    end else
      ErrorItem := ErrorsList.Items[i];

    ErrorItem^.ErrorTime := Now();
    ErrorItem^.ErrorMessage := AErrorMessage;

    ErrorsList.Add(ErrorItem);
  finally
    ErrorsSync.EndWrite;
  end;
end;

function GetLastErrorGoogleCalendar: string;
var
  i, n: integer;
  ErrorItem: PErrorItem;
begin
  Result := '';
  ErrorsSync.BeginRead;
  try

    n := -1;
    for i:=0 to ErrorsList.Count-1 do
      if PErrorItem(ErrorsList.Items[i])^.ThreadID = GetCurrentThreadId then begin
        n := i;
        Break;
      end;

    if n<>-1 then begin
      Result := PErrorItem(ErrorsList.Items[n])^.ErrorMessage;
    end;
  finally
    ErrorsSync.EndRead;
  end;
end;

function GetResponseState(AhRequest: HINTERNET): string;
var
  idx: Cardinal;
  ansLen: Cardinal;
  ReqInfo: BOOL;
begin
  Result := ' ';
  ansLen := 1;
  idx := 0;
  ReqInfo := HttpQueryInfoA(AhRequest, HTTP_QUERY_STATUS_CODE, PAnsiChar(Result), ansLen, idx);
  if not ReqInfo then begin
    if GetLastError = ERROR_INSUFFICIENT_BUFFER then begin
      Result := StringOfChar(' ', ansLen);
      idx := 0;
      ReqInfo := HttpQueryInfoA(AhRequest, HTTP_QUERY_STATUS_CODE, PAnsiChar(Result), ansLen, idx);
    end;
    if not ReqInfo then begin
      Result := ' ';
    end;
  end;
  Result := Trim(Result);
end;

function GetResponseBody(AhRequest: HINTERNET): string;
var
  answer: string;
  ansLen: Cardinal;
  ReqInfo: BOOL;
begin
  Result := '';
  SetLength(answer, 1024);
  ansLen := 0;
  repeat
    ReqInfo := InternetReadFile(AhRequest, PAnsiChar(answer), Length(answer), ansLen);
    if ReqInfo then begin
      Result := Result + Copy(answer, 1, ansLen);
    end else begin
      Break;
    end;
  until (ReqInfo and (ansLen=0));
end;

function GetFirstRedirectUrl(AUrlsSource: string): string;
begin
  Result := '';
  with TStringList.Create do try
    Text := AUrlsSource;
    if Count>1 then
      Result := Strings[0];
  finally
    Free;
  end;
end;

function CrackUrl(AURL: string; var AHost, APath: string; var APort: word; var AScheme: TInternetScheme): boolean;
var
  UrlParts: URL_COMPONENTS;
begin
  AHost := ''; APath := ''; APort := 0; AScheme := 0;
  FillChar(UrlParts, SizeOf(URL_COMPONENTS), 0);
  with UrlParts do begin
    lpszScheme := nil;
    dwSchemeLength := INTERNET_MAX_SCHEME_LENGTH;
    lpszHostName := nil;
    dwHostNameLength := INTERNET_MAX_HOST_NAME_LENGTH;
    lpszUrlPath := nil;
    dwUrlPathLength := INTERNET_MAX_PATH_LENGTH;
    dwStructSize := SizeOf(UrlParts);
  end;
  Result := InternetCrackUrl(PAnsiChar(AURL), Length(AURL), 0, UrlParts);
  if not Result then Exit;

  AHost := Copy(UrlParts.lpszHostName, 1, UrlParts.dwHostNameLength);
  APath := Copy(UrlParts.lpszUrlPath, 1, UrlParts.dwUrlPathLength);
  APort := UrlParts.nPort;
  AScheme := UrlParts.nScheme;
end;

function GetPrimaryAccessToken(Adm: TdbmDental): boolean;
var
  PInetHandle: pointer;
  hConnection: HINTERNET;
  hRequest: HINTERNET;
  AcceptTypes: array of PChar;
  hdr: PAnsiChar;
  body: PAnsiChar;
  bodystr: string;
  ReqResult: BOOL;

  ds: TpFIBDataSet;
  tr: TpFIBTransaction;
  tokenURI: string;
  URL: string;
  Port: integer;
  redirURIsText: string;
  _Host, _Path: string;
  nPort: Word;
  nScheme: TInternetScheme;

  jsonObj: ISuperObject;
  TokenContent: widestring;
  jsonValue: string;
begin
  Result := False;
  ds := Adm.CreateDS;
  tr := Adm.CreateTr(trSingleLockTrans);
  try
    ds.Transaction := tr;
    ds.UpdateTransaction := tr;
    ds.AutoUpdateOptions.UpdateTableName := 'GOOGLESECRET';
    ds.AutoUpdateOptions.KeyFields := 'GID';
    ds.Options := ds.Options + [poUseSelectForLock];
    ds.PrepareOptions := ds.PrepareOptions - [psAskRecordCount];
    tr.StartTransaction;
    try
      ds.SelectSQL.Text := 'select * from GoogleSecret for update with lock';
      ds.Open;

      if ds.IsEmpty then begin
        SetLastErrorGoogleCalendar('Secret ещё не импортирован');
        tr.Rollback;
        Exit;
      end;

      if VariantAsAnsiString(ds.FieldByName('AUTHORIZATIONCODE').Value)='' then begin
        SetLastErrorGoogleCalendar('Authorization Code ещё не получен');
        tr.Rollback;
        Exit;
      end;

      tokenURI := ds.FieldByName('TokenURI').Value;
      if not CrackUrl(tokenURI, _Host, _Path, nPort, nScheme) then begin
        SetLastErrorGoogleCalendar('Ошибка URL для получения токена (1); GetLastError='+IntToStr(GetLastError));
        tr.Rollback;
        Exit;
      end;
      if nScheme = INTERNET_SCHEME_HTTP then
        Port := INTERNET_DEFAULT_HTTP_PORT
      else
        Port := INTERNET_DEFAULT_HTTPS_PORT;

      PInetHandle := InternetOpenA(PAnsiChar('Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0)'),
                                   INTERNET_OPEN_TYPE_PRECONFIG,
                                   nil,
                                   nil,
                                   INTERNET_FLAG_DONT_CACHE
                                  );
      try
        if PInetHandle=nil then begin
          SetLastErrorGoogleCalendar('Ошибка инициализации интернет-соединения (1); GetLastError='+IntToStr(GetLastError));
          tr.Rollback;
          Exit;
        end;

        hConnection := InternetConnectA(PInetHandle, PAnsiChar(_Host),
                                        Port, nil, nil, INTERNET_SERVICE_HTTP, 0, 1);
        try
          if hConnection=nil then begin
            SetLastErrorGoogleCalendar('Ошибка открытия соединения (1); GetLastError='+IntToStr(GetLastError));
            tr.Rollback;
            Exit;
          end;

          SetLength(AcceptTypes, 4);
          AcceptTypes[0] := PChar('application/x-www-form-urlencoded');
          AcceptTypes[1] := PChar('application/*');
          AcceptTypes[2] := PChar('text/*');
          AcceptTypes[3] := nil;
          hRequest := HttpOpenRequestA(hConnection, PAnsiChar('POST'), PAnsiChar(_Path), nil, nil, Pointer(AcceptTypes),
                                       INTERNET_FLAG_SECURE,
                                       1);
          try
            if hRequest=nil then begin
              SetLastErrorGoogleCalendar('Ошибка передачи данных (1); GetLastError='+IntToStr(GetLastError));
              tr.Rollback;
              Exit;
            end;

            redirURIsText := GetFirstRedirectUrl(VariantAsAnsiString(ds.FieldByName('REDIRURI').Value));

            hdr := 'Content-Type: application/x-www-form-urlencoded';
            bodystr := '';
            bodystr := bodystr + 'code='+ds.FieldByName('AUTHORIZATIONCODE').Value+'&';
            bodystr := bodystr + 'client_id='+ds.FieldByName('CLIENTID').Value+'&';
            bodystr := bodystr + 'client_secret='+ds.FieldByName('SECRET').Value+'&';
            bodystr := bodystr + 'redirect_uri='+redirURIsText+'&';
            bodystr := bodystr + 'grant_type=authorization_code';

            body := PAnsiChar(bodystr);
            ReqResult := HttpSendRequestA(hRequest, hdr, Length(hdr), body, Length(body));
            if not ReqResult then begin
              SetLastErrorGoogleCalendar('Ошибка получения данных (1); GetLastError='+IntToStr(GetLastError));
              tr.Rollback;
              Exit;
            end;

            if GetResponseState(hRequest)<>'200' then begin
              bodystr := GetResponseBody(hRequest);
              SetLastErrorGoogleCalendar('Ошибка запроса (1)' + #13#10 + bodystr);
              tr.Rollback;
              Exit;
            end;

            TokenContent := GetResponseBody(hRequest);
            jsonObj := TSuperObject.ParseString(PWideChar(TokenContent), True);
            if jsonObj<>nil then begin
              ds.Edit;
              jsonValue := jsonObj.AsObject.S['access_token'];
              ds.FieldByName('AccessToken').Value := jsonValue;
              jsonValue := jsonObj.AsObject.S['refresh_token'];
              ds.FieldByName('RefreshToken').Value := jsonValue;
              jsonValue := jsonObj.AsObject.S['token_type'];
              ds.FieldByName('TokenType').Value   := jsonValue;
              ds.FieldByName('Expires').Value     := jsonObj.AsObject.I['expires_in'];
              ds.FieldByName('ReceiveTime').Value := Now();
              ds.Post;
              Result := True;
            end else begin
              SetLastErrorGoogleCalendar('Ошибка обработки ответа (1)');
              tr.Rollback;
              Exit;
            end;

          finally
            InternetCloseHandle(hRequest);
          end;
        finally
          InternetCloseHandle(hConnection);
        end;
      finally
        InternetCloseHandle(PInetHandle);
      end;

      tr.Commit;
    except
      on E:Exception do begin
        tr.Rollback;
        Result := False;
        SetLastErrorGoogleCalendar('Фатальная ошибка (1)');
      end;
    end;
  finally
    Adm.CloseTR(tr);
    Adm.CloseDS(ds);
  end;
end;

function GetNewToken(ATokenHost, ATokenPath: string; ATokenPort: integer;
                     ARefreshToken, AClientID, AClientSecret: string): string;
var
  PInetHandle: pointer;
  hConnection: HINTERNET;
  hRequest: HINTERNET;
  AcceptTypes: array of PChar;
  hdr: PAnsiChar;
  body: PAnsiChar;
  bodystr: string;
  ReqResult: BOOL;
begin
  Result := '';
  PInetHandle := InternetOpenA(PAnsiChar('Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0)'),
                               INTERNET_OPEN_TYPE_PRECONFIG,
                               nil,
                               nil,
                               INTERNET_FLAG_DONT_CACHE
                              );
  try
    if PInetHandle=nil then begin
      SetLastErrorGoogleCalendar('Ошибка инициализации интернет-соединения (2); GetLastError='+IntToStr(GetLastError));
      Exit;
    end;

    hConnection := InternetConnectA(PInetHandle, PAnsiChar(ATokenHost), ATokenPort,
                                    nil, nil, INTERNET_SERVICE_HTTP, 0, 1);
    try
      if hConnection=nil then begin
        SetLastErrorGoogleCalendar('Ошибка открытия соединения (2); GetLastError='+IntToStr(GetLastError));
        Exit;
      end;

      SetLength(AcceptTypes, 4);
      AcceptTypes[0] := PChar('application/x-www-form-urlencoded');
      AcceptTypes[1] := PChar('application/*');
      AcceptTypes[2] := PChar('text/*');
      AcceptTypes[3] := nil;
      hRequest := HttpOpenRequestA(hConnection, PAnsiChar('POST'), PAnsiChar(ATokenPath), nil, nil, Pointer(AcceptTypes),
                                   INTERNET_FLAG_SECURE,
                                   1);
      try
        if hRequest=nil then begin
          SetLastErrorGoogleCalendar('Ошибка передачи данных (2); GetLastError='+IntToStr(GetLastError));
          Exit;
        end;

        hdr := 'Content-Type: application/x-www-form-urlencoded';
        bodystr := '';
        bodystr := bodystr + 'refresh_token='+ARefreshToken+'&';
        bodystr := bodystr + 'client_id='+AClientID+'&';
        bodystr := bodystr + 'client_secret='+AClientSecret+'&';
        bodystr := bodystr + 'grant_type=refresh_token';

        body := PAnsiChar(bodystr);
        ReqResult := HttpSendRequestA(hRequest, hdr, Length(hdr), body, Length(body));
        if not ReqResult then begin
          SetLastErrorGoogleCalendar('Ошибка получения данных (2); GetLastError='+IntToStr(GetLastError));
          Exit;
        end;

        if GetResponseState(hRequest)<>'200' then begin
          bodystr := GetResponseBody(hRequest);
          SetLastErrorGoogleCalendar('Ошибка запроса (2)' + #13#10 + bodystr);
          Exit;
        end;

        {}
        Result := GetResponseBody(hRequest);

      finally
        InternetCloseHandle(hRequest);
      end;
    finally
      InternetCloseHandle(hConnection);
    end;
  finally
    InternetCloseHandle(PInetHandle);
  end;
end;

function ReadToken(Adm: TdbmDental; AForceGetToken: boolean = False): string;
var
  ds: TpFIBDataSet;
  tr: TpFIBTransaction;
  LastTokenTime: TDateTime;
  Expiration: integer;
  NewTokenContent: WideString;
  jsonObj: ISuperObject;
  dbm, dbmForThread: TdbmDental;

  ClientID: string;
  ClientSecret: string;
  RefreshToken: string;
  TokenType: string;
  tokenURI: string;
  Port: integer;
  _Host, _Path: string;
  nPort: Word;
  nScheme: TInternetScheme;
  NeedFreeDM: boolean;
begin
  Result := '';
  NeedFreeDM := False;

  if GetCurrentThreadId=MainThreadID then begin
    if Adm=nil then
      dbm := dbmDental
    else
      dbm := Adm;
  end else begin
    if Adm=nil then begin
      dbmForThread := TdbmDental.Create(Application);
      dbm := dbmForThread;
      NeedFreeDM := True;
    end else begin
      dbm := Adm;
    end;
  end;

  try
    ds := dbm.CreateDS;
    tr := dbm.CreateTr(trSingleLockTrans);
    try
      ds.Transaction := tr;
      ds.UpdateTransaction := tr;
      tr.StartTransaction;
      try
        ds.SelectSQL.Text := 'select * from GoogleSecret';
        ds.AutoUpdateOptions.KeyFields := 'GID';
        ds.AutoUpdateOptions.UpdateTableName := 'GOOGLESECRET';
        ds.Open;
        ds.First;
        LastTokenTime := ds.FieldByName('ReceiveTime').AsDateTime;
        Expiration    := ds.FieldByName('Expires').AsInteger;

        if ((LastTokenTime+(Expiration/(24*60*60))) < (Now()+(5/(24*60)))) or AForceGetToken then begin
          RefreshToken  := ds.FieldByName('RefreshToken').AsString;
          ClientID      := ds.FieldByName('ClientID').AsString;
          ClientSecret  := ds.FieldByName('Secret').AsString;
          tokenURI := ds.FieldByName('TokenURI').Value;
          if not CrackUrl(tokenURI, _Host, _Path, nPort, nScheme) then begin
            SetLastErrorGoogleCalendar('Ошибка URL для получения токена (2); GetLastError='+IntToStr(GetLastError));
            tr.Rollback;
            Exit;
          end;
          if nScheme = INTERNET_SCHEME_HTTP then
            Port := INTERNET_DEFAULT_HTTP_PORT
          else
            Port := INTERNET_DEFAULT_HTTPS_PORT;

          NewTokenContent := GetNewToken(_Host, _Path, Port, Refreshtoken, Clientid, ClientSecret);
          if NewTokenContent='' then begin
            SetLastErrorGoogleCalendar(GetLastErrorGoogleCalendar+#13#10+'Ошибка получения нового токена (3); GetLastError='+IntToStr(GetLastError));
            tr.Rollback;
            Exit;
          end;

          jsonObj := TSuperObject.ParseString(PWideChar(NewTokenContent), True);
          if jsonObj<>nil then begin
            ds.Edit;
            Result := jsonObj.AsObject.S['access_token'];
            ds.FieldByName('AccessToken').Value := Result;
            TokenType   := jsonObj.AsObject.S['token_type'];
            ds.FieldByName('TokenType').Value   := TokenType;
            ds.FieldByName('Expires').Value     := jsonObj.AsObject.I['expires_in'];
            ds.FieldByName('ReceiveTime').Value := Now();
            ds.Post;
          end;
        end else begin
          Result := ds.FieldByName('AccessToken').AsString;
          if Result='' then begin
            SetLastErrorGoogleCalendar('Ошибка получения токена (3); GetLastError='+IntToStr(GetLastError));
          end;
        end;

        tr.Commit;
      except
        tr.Rollback;
        raise;
      end;
    finally
      dbm.CloseTR(tr);
      dbm.CloseDS(ds);
    end;

  finally
    if NeedFreeDM then
      dbmForThread.Free;
  end;
end;


function GetCalendarList(var jsonList: widestring; var NeedNewToken: boolean): boolean;
var
  AccessToken: string;
  PInetHandle: pointer;
  hConnection: HINTERNET;
  hRequest: HINTERNET;
  AcceptTypes: array of PChar;
  hdr: PAnsiChar;
  hdrstr: string;
  ReqResult: BOOL;
  answerText: WideString;
  URL: string;
  jsonObj, errorObj, theError: ISuperObject;
begin
  Result := False;
  NeedNewToken := False;
  AccessToken := ReadToken(nil); // потому что GetCalendarList всегда вызывается только из-под проекта DentalA,
                                 // а там в качестве дата-модуля будет использован глобальный dbmDental
  if AccessToken = '' then begin
    // Сообщение об ошибке уже сформировали в ReadToken
    Exit;
  end;

  PInetHandle := InternetOpenA(PAnsiChar('Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0)'),
                               INTERNET_OPEN_TYPE_PRECONFIG,
                               nil,
                               nil,
                               INTERNET_FLAG_DONT_CACHE
                              );
  try
    if PInetHandle=nil then begin
      SetLastErrorGoogleCalendar('Ошибка инициализации интернет-соединения (4); GetLastError='+IntToStr(GetLastError));
      Exit;
    end;

    hConnection := InternetConnectA(PInetHandle, PAnsiChar('www.googleapis.com'),
                                    INTERNET_DEFAULT_HTTPS_PORT,
                                    nil, nil, INTERNET_SERVICE_HTTP, 0, 1);
    try
      if hConnection=nil then begin
        SetLastErrorGoogleCalendar('Ошибка открытия соединения (4); GetLastError='+IntToStr(GetLastError));
        Exit;
      end;

      SetLength(AcceptTypes, 4);
      AcceptTypes[0] := PChar('application/x-www-form-urlencoded');
      AcceptTypes[1] := PChar('application/*');
      AcceptTypes[2] := PChar('text/*');
      AcceptTypes[3] := nil;

      // не заморачиваемся с Pagination, поэтому без единого параметра
      URL := '/calendar/v3/users/me/calendarList';
      hRequest := HttpOpenRequestA(hConnection, PAnsiChar('GET'),
                                   PAnsiChar(URL),
                                   nil, nil, Pointer(AcceptTypes),
                                   INTERNET_FLAG_SECURE,
                                   1);
      try
        if hRequest=nil then begin
          SetLastErrorGoogleCalendar('Ошибка передачи данных (4); GetLastError='+IntToStr(GetLastError));
          Exit;
        end;

        hdrstr := '';
        hdrstr := hdrstr + 'Authorization: Bearer '+AccessToken + #13#10;
        hdr := PAnsiChar(hdrstr);

        ReqResult := HttpSendRequestA(hRequest, hdr, Length(hdr), nil, 0);
        if not ReqResult then begin
          SetLastErrorGoogleCalendar('Ошибка получения данных (4); GetLastError='+IntToStr(GetLastError));
          Exit;
        end;

        if GetResponseState(hRequest)='200' then begin
          jsonList := GetResponseBody(hRequest);
          Result := True;
        end else begin
          // проверка тела на ошибки
          answerText := GetResponseBody(hRequest);
          SetLastErrorGoogleCalendar('Ошибка запроса (4)' + #13#10 + answerText);

          // проверка на ошибку авторизации, пора менять access token типа
          jsonObj := TSuperObject.ParseString(PWideChar(answerText), True);
          errorObj := jsonObj['error'];
          if errorObj<>nil then begin
            for theError in errorObj['errors'] do begin
              if (WideCompareText(theError.AsObject.S['reason'], 'authError')=0)
                 and (WideCompareText(theError.AsObject.S['message'], 'Invalid Credentials')=0)
              then begin
                NeedNewToken := True;
                Break;
              end;
            end;
          end;
        end;

      finally
        InternetCloseHandle(hRequest);
      end;
    finally
      InternetCloseHandle(hConnection);
    end;
  finally
    InternetCloseHandle(PInetHandle);
  end;
end;

function GetCalendarList(var jsonList: widestring): boolean;
var
  NeedNewToken: boolean;
begin
  Result := GetCalendarList(jsonList, NeedNewToken);
  if (not Result) and NeedNewToken then begin
    if ReadToken(nil, True)<>'' then // см. примечание к вызову ReadToken в GetCalendarList
      Result := GetCalendarList(jsonList, NeedNewToken);
  end;
end;

function GetCalendarItems(Adm: TdbmDental; ACalendarID: widestring; var jsonList: widestring; var NeedNewToken: boolean): boolean; overload;
var
  AccessToken: string;
  PInetHandle: pointer;
  hConnection: HINTERNET;
  hRequest: HINTERNET;
  AcceptTypes: array of PChar;
  hdr: PAnsiChar;
  hdrstr: string;
  ReqResult: BOOL;
  answerText: WideString;
  coreURL, URL: string;
  jsonEvents, jsonObj, errorObj, theError: ISuperObject;
  jsonEventItems: TSuperArray;
  i: integer;
  pageToken: string;
  ErrorSignal: boolean;
  ResponsePart: WideString;
begin
  Result := False;
  NeedNewToken := False;
  ErrorSignal := False;
  AccessToken := ReadToken(Adm);
  if AccessToken = '' then begin
    // Сообщение об ошибке уже сформировали в ReadToken
    Exit;
  end;

  PInetHandle := InternetOpenA(PAnsiChar('Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0)'),
                               INTERNET_OPEN_TYPE_PRECONFIG,
                               nil,
                               nil,
                               INTERNET_FLAG_DONT_CACHE
                              );
  try
    if PInetHandle=nil then begin
      SetLastErrorGoogleCalendar('Ошибка инициализации интернет-соединения (5); GetLastError='+IntToStr(GetLastError));
      Exit;
    end;

    hConnection := InternetConnectA(PInetHandle, PAnsiChar('www.googleapis.com'),
                                    INTERNET_DEFAULT_HTTPS_PORT,
                                    nil, nil, INTERNET_SERVICE_HTTP, 0, 1);
    try
      if hConnection=nil then begin
        SetLastErrorGoogleCalendar('Ошибка открытия соединения (5); GetLastError='+IntToStr(GetLastError));
        Exit;
      end;

      SetLength(AcceptTypes, 4);
      AcceptTypes[0] := PChar('application/x-www-form-urlencoded');
      AcceptTypes[1] := PChar('application/*');
      AcceptTypes[2] := PChar('text/*');
      AcceptTypes[3] := nil;

      coreURL := '/calendar/v3/calendars/'+ACalendarID+'/events';
      //coreURL := coreURL+'?'+'singleEvents=true';
      coreURL := coreURL+'?'+'timeMin='+LocalTimeToRTF3339(CurrentDate());

      hdrstr := '';
      hdrstr := hdrstr + 'Authorization: Bearer '+AccessToken + #13#10;
      hdr := PAnsiChar(hdrstr);

      pageToken := '';

      repeat
        if pageToken<>'' then
          URL := coreURL+'&'+'pageToken='+pageToken
        else
          URL := coreURL;

        hRequest := HttpOpenRequestA(hConnection, PAnsiChar('GET'),
                                     PAnsiChar(URL),
                                     nil, nil, Pointer(AcceptTypes),
                                     INTERNET_FLAG_SECURE,
                                     1);
        try
          if hRequest=nil then begin
            SetLastErrorGoogleCalendar('Ошибка передачи данных (5); GetLastError='+IntToStr(GetLastError));
            Exit;
          end;

          ReqResult := HttpSendRequestA(hRequest, hdr, Length(hdr), nil, 0);
          if not ReqResult then begin
            SetLastErrorGoogleCalendar('Ошибка получения данных (5); GetLastError='+IntToStr(GetLastError));
            Exit;
          end;


          if GetResponseState(hRequest)='200' then begin
            try
              if jsonEvents=nil then begin
                jsonEvents := SO('{"items": []}');
              end;
              ResponsePart := GetResponseBody(hRequest);
              jsonObj := TSuperObject.ParseString(PWideChar(ResponsePart), True);
              try
                pageToken := jsonObj.S['nextPageToken'];
                jsonEventItems := jsonObj.A['items'];
                //jsonEvents.O['items'] := SO('[]');
                for i:=0 to jsonEventItems.Length-1 do
                  jsonEvents.A['items'].Add(jsonEventItems.O[i]);
              finally
                jsonObj := nil;
              end;
            except
              on E:Exception do begin
                SetLastErrorGoogleCalendar(E.Message);
                Exit;
              end;
            end;
          end else begin
            ErrorSignal := True;
            // проверка тела на ошибки
            answerText := GetResponseBody(hRequest);
            SetLastErrorGoogleCalendar('Ошибка запроса (4)' + #13#10 + answerText);

            // проверка на ошибку авторизации, пора менять access token типа
            jsonObj := TSuperObject.ParseString(PWideChar(answerText), True);
            errorObj := jsonObj['error'];
            if errorObj<>nil then begin
              for theError in errorObj['errors'] do begin
                if (WideCompareText(theError.AsObject.S['reason'], 'authError')=0)
                   and (WideCompareText(theError.AsObject.S['message'], 'Invalid Credentials')=0)
                then begin
                  NeedNewToken := True;
                  Break;
                end;
              end;
            end;
          end;

        finally
          InternetCloseHandle(hRequest);
          hRequest := nil;
        end;
      until (pageToken='') or ErrorSignal;

      if not ErrorSignal then begin
        jsonList := jsonEvents.AsString;
        Result := True;
      end;

    finally
      InternetCloseHandle(hConnection);
    end;
  finally
    InternetCloseHandle(PInetHandle);
  end;
end;

function GetCalendarItems(Adm: TdbmDental; ACalendarID: widestring; var jsonList: widestring): boolean; overload;
var
  NeedNewToken: boolean;
begin
  Result := GetCalendarItems(Adm, ACalendarID, jsonList, NeedNewToken);
  if (not Result) and NeedNewToken then begin
    if ReadToken(Adm, True)<>'' then
      Result := GetCalendarItems(Adm, ACalendarID, jsonList, NeedNewToken);
  end;
end;

function DeleteEvent(Adm: TdbmDental; ACalendarID, AEventID: widestring; var NeedNewToken: boolean): boolean; overload;
var
  AccessToken: string;
  PInetHandle: pointer;
  hConnection: HINTERNET;
  hRequest: HINTERNET;
  AcceptTypes: array of PChar;
  hdr: PAnsiChar;
  hdrstr: string;
  ReqResult: BOOL;
  RespStatus: string;
  answerText: WideString;
  URL: string;
  jsonObj, errorObj, theError: ISuperObject;
begin
  Result := False;
  NeedNewToken := False;
  AccessToken := ReadToken(Adm);
  if AccessToken = '' then begin
    // Сообщение об ошибке уже сформировали в ReadToken
    Exit;
  end;

  PInetHandle := InternetOpenA(PAnsiChar('Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0)'),
                               INTERNET_OPEN_TYPE_PRECONFIG,
                               nil,
                               nil,
                               INTERNET_FLAG_DONT_CACHE
                              );
  try
    if PInetHandle=nil then begin
      SetLastErrorGoogleCalendar('Ошибка инициализации интернет-соединения (6); GetLastError='+IntToStr(GetLastError));
      Exit;
    end;

    hConnection := InternetConnectA(PInetHandle, PAnsiChar('www.googleapis.com'),
                                    INTERNET_DEFAULT_HTTPS_PORT,
                                    nil, nil, INTERNET_SERVICE_HTTP, 0, 1);
    try
      if hConnection=nil then begin
        SetLastErrorGoogleCalendar('Ошибка открытия соединения (6); GetLastError='+IntToStr(GetLastError));
        Exit;
      end;

      SetLength(AcceptTypes, 4);
      AcceptTypes[0] := PChar('application/x-www-form-urlencoded');
      AcceptTypes[1] := PChar('application/*');
      AcceptTypes[2] := PChar('text/*');
      AcceptTypes[3] := nil;

      URL := '/calendar/v3/calendars/' + ACalendarId + '/events/' + AEventId;
      hRequest := HttpOpenRequestA(hConnection, PAnsiChar('DELETE'),
                                   PAnsiChar(URL),
                                   nil, nil, Pointer(AcceptTypes),
                                   INTERNET_FLAG_SECURE,
                                   1);
      try
        if hRequest=nil then begin
          SetLastErrorGoogleCalendar('Ошибка передачи данных (6); GetLastError='+IntToStr(GetLastError));
          Exit;
        end;

        hdrstr := '';
        hdrstr := hdrstr + 'Authorization: Bearer '+AccessToken + #13#10;
        hdr := PAnsiChar(hdrstr);

        ReqResult := HttpSendRequestA(hRequest, hdr, Length(hdr), nil, 0);
        if not ReqResult then begin
          SetLastErrorGoogleCalendar('Ошибка получения данных (6); GetLastError='+IntToStr(GetLastError));
          Exit;
        end;

        RespStatus := GetResponseState(hRequest);
        if (StrtoIntDef(RespStatus,0)>=200) and (StrtoIntDef(RespStatus,0)<=299) then begin
          Result := True;
        end else begin
          // проверка тела на ошибки
          answerText := GetResponseBody(hRequest);
          SetLastErrorGoogleCalendar('Ошибка запроса (6)' + #13#10 + answerText);

          // проверка на ошибку авторизации, пора менять access token типа
          jsonObj := TSuperObject.ParseString(PWideChar(answerText), True);
          errorObj := jsonObj['error'];
          if errorObj<>nil then begin
            for theError in errorObj['errors'] do begin
              if (WideCompareText(theError.AsObject.S['reason'], 'authError')=0)
                 and (WideCompareText(theError.AsObject.S['message'], 'Invalid Credentials')=0)
              then begin
                NeedNewToken := True;
                Break;
              end;
            end;
          end;
        end;

      finally
        InternetCloseHandle(hRequest);
      end;
    finally
      InternetCloseHandle(hConnection);
    end;
  finally
    InternetCloseHandle(PInetHandle);
  end;
end;

function DeleteEvent(Adm: TdbmDental; ACalendarID, AEventID: widestring): boolean; overload;
var
  NeedNewToken: boolean;
begin
  Result := DeleteEvent(Adm, ACalendarID, AEventID, NeedNewToken);
  if (not Result) and NeedNewToken then begin
    if ReadToken(Adm, True)<>'' then
      Result := DeleteEvent(Adm, ACalendarID, AEventID, NeedNewToken);
  end;
end;

function AddUpdateEvent(Adm: TdbmDental; AHttpMethod, AMethodURL: string; AEvent: ISuperObject; var NeedNewToken: boolean): boolean; overload;
var
  AccessToken: string;
  PInetHandle: pointer;
  hConnection: HINTERNET;
  hRequest: HINTERNET;
  AcceptTypes: array of PChar;
  hdr: PAnsiChar;
  hdrstr: string;
  body: PAnsiChar;
  bodystr: string;
  ReqResult: BOOL;
  RespStatus: string;
  answerText: WideString;
  jsonObj, errorObj, theError: ISuperObject;
begin
  Result := False;
  NeedNewToken := False;
  AccessToken := ReadToken(Adm);
  if AccessToken = '' then begin
    // Сообщение об ошибке уже сформировали в ReadToken
    Exit;
  end;

  PInetHandle := InternetOpenA(PAnsiChar('Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0)'),
                               INTERNET_OPEN_TYPE_PRECONFIG,
                               nil,
                               nil,
                               INTERNET_FLAG_DONT_CACHE
                              );
  try
    if PInetHandle=nil then begin
      SetLastErrorGoogleCalendar('Ошибка инициализации интернет-соединения (7); GetLastError='+IntToStr(GetLastError));
      Exit;
    end;

    hConnection := InternetConnectA(PInetHandle, PAnsiChar('www.googleapis.com'),
                                    INTERNET_DEFAULT_HTTPS_PORT,
                                    nil, nil, INTERNET_SERVICE_HTTP, 0, 1);
    try
      if hConnection=nil then begin
        SetLastErrorGoogleCalendar('Ошибка открытия соединения (7); GetLastError='+IntToStr(GetLastError));
        Exit;
      end;

//      SetLength(AcceptTypes, 4);
//      AcceptTypes[0] := PChar('application/x-www-form-urlencoded');
//      AcceptTypes[1] := PChar('application/*');
//      AcceptTypes[2] := PChar('text/*');
//      AcceptTypes[3] := nil;
      SetLength(AcceptTypes, 2);
      AcceptTypes[0] := PChar('application/json');
      AcceptTypes[1] := nil;

      hRequest := HttpOpenRequestA(hConnection, PAnsiChar(AHttpMethod),
                                   PAnsiChar(AMethodURL),
                                   nil, nil, Pointer(AcceptTypes),
                                   INTERNET_FLAG_SECURE,
                                   1);
      try
        if hRequest=nil then begin
          SetLastErrorGoogleCalendar('Ошибка передачи данных (7); GetLastError='+IntToStr(GetLastError));
          Exit;
        end;

        hdrstr := '';
        hdrstr := hdrstr + 'Authorization: Bearer '+AccessToken + #13#10;
        hdrstr := hdrstr + 'Content-Type: application/json' + #13#10;
        hdr := PAnsiChar(Trim(hdrstr));

        bodystr := AEvent.AsString;
        body := PAnsiChar(bodystr);
        ReqResult := HttpSendRequestA(hRequest, hdr, Length(hdr), body, Length(body));

        if not ReqResult then begin
          SetLastErrorGoogleCalendar('Ошибка получения данных (7); GetLastError='+IntToStr(GetLastError));
          Exit;
        end;

        RespStatus := GetResponseState(hRequest);
        if (StrtoIntDef(RespStatus,0)>=200) and (StrtoIntDef(RespStatus,0)<=299) then begin
          Result := True;
        end else begin
          // проверка тела на ошибки
          answerText := GetResponseBody(hRequest);
          SetLastErrorGoogleCalendar('Ошибка запроса (7)' + #13#10 + answerText);

          // проверка на ошибку авторизации, пора менять access token типа
          jsonObj := TSuperObject.ParseString(PWideChar(answerText), True);
          errorObj := jsonObj['error'];
          if errorObj<>nil then begin
            for theError in errorObj['errors'] do begin
              if (WideCompareText(theError.AsObject.S['reason'], 'authError')=0)
                 and (WideCompareText(theError.AsObject.S['message'], 'Invalid Credentials')=0)
              then begin
                NeedNewToken := True;
                Break;
              end;
            end;
          end;
        end;

      finally
        InternetCloseHandle(hRequest);
      end;
    finally
      InternetCloseHandle(hConnection);
    end;
  finally
    InternetCloseHandle(PInetHandle);
  end;
end;

function AddUpdateEvent(Adm: TdbmDental; AHttpMethod, AMethodURL: string; AEvent: ISuperObject): boolean; overload;
var
  NeedNewToken: boolean;
begin
  Result := AddUpdateEvent(Adm, AHttpMethod, AMethodURL, AEvent, NeedNewToken);
  if (not Result) and NeedNewToken then begin
    if ReadToken(Adm, True)<>'' then
      Result := AddUpdateEvent(Adm, AHttpMethod, AMethodURL, AEvent, NeedNewToken);
  end;
end;

function RealBias: integer;
var
  NowTime, EncodedNow: TDateTime;
  SysTime: _SYSTEMTIME;
begin
  Result := 0;
  NowTime := Now();
  GetSystemTime(SysTime);
  EncodedNow := EncodeDate(SysTime.wYear, SysTime.wMonth, SysTime.wDay) +
                EncodeTime(SysTime.wHour, SysTime.wMinute, SysTime.wSecond, SysTime.wMilliseconds);
  Result := Round((NowTime - EncodedNow)*24);
end;

function LocalTimeToRTF3339(ADateTime: TDateTime): string;
var
  Bias: integer;
  BiasSign: string;
begin
  Bias := RealBias;
  if Bias>=0 then BiasSign := '+' else BiasSign := '-';
  Result := FormatDateTime('YYYY"-"MM"-"DD"T"hh":"nn":"ss".000Z"', ADateTime-Bias/24);
            //+BiasSign+Format('%2.2d:00', [Abs(Bias)]);
end;

{ TErrorsList }

procedure TErrorsList.Notify(Ptr: Pointer; Action: TListNotification);
begin
  if Action=lnDeleted then
    Dispose(Ptr);
end;

initialization
  ErrorsSync := TMultiReadExclusiveWriteSynchronizer.Create;
  ErrorsList := TErrorsList.Create;

finalization
  ErrorsList.Free;
  ErrorsSync.Free;

end.

