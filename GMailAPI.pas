unit GMailAPI;

interface
uses
  Classes, uTransDB;

function CreateDraft(Receiver: string; Subject: string; Attachments: TStringList): boolean; overload;
function GetLastErrorGMail: string;
function GetPrimaryAccessToken(Adm: TdbmTrans): boolean;

implementation
uses
  WinInet, JvStrings, SuperObject, pFIBDataSet, pFIBDataBase, AbstractDBA,
  SysUtils, Windows, pFIBProps, CommonDefinitions;

var
  ClientID: string;
  ClientSecret: string;
  RefreshToken: string;
  TokenType: string;
  UserEmail: string;
  LastErrorGMail: string;

function GetLastErrorGMail: string;
begin Result := LastErrorGMail; end;

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

function GetPrimaryAccessToken(Adm: TdbmTrans): boolean;
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
  redirURIsText: string;
  _Path: string;

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
    ds.AutoUpdateOptions.UpdateTableName := 'GMAIL';
    ds.AutoUpdateOptions.KeyFields := 'GMAILID';
    ds.Options := ds.Options + [poUseSelectForLock];
    ds.PrepareOptions := ds.PrepareOptions - [psAskRecordCount];
    try
      tr.StartTransaction;
      ds.SelectSQL.Text := 'select * from GMail for update with lock';
      ds.Open;

      if VariantAsAnsiString(ds.FieldByName('AUTHORIZATIONCODE').Value)='' then begin
        LastErrorGMail := 'Authorization Code ещё не получен';
        tr.Rollback;
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
          LastErrorGMail := 'Ошибка инициализации интернет-соединения (1)';
          tr.Rollback;
          Exit;
        end;

        tokenURI := 'accounts.google.com';
        _Path := '/o/oauth2/token';

        hConnection := InternetConnectA(PInetHandle, PAnsiChar(tokenURI),
                                        INTERNET_DEFAULT_HTTPS_PORT, nil, nil, INTERNET_SERVICE_HTTP, 0, 1);
        try
          if hConnection=nil then begin
            LastErrorGMail := 'Ошибка открытия соединения (1)';
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
              LastErrorGMail := 'Ошибка передачи данных (1)';
              tr.Rollback;
              Exit;
            end;

            redirURIsText := 'urn:ietf:wg:oauth:2.0:oob';

            hdr := 'Content-Type: application/x-www-form-urlencoded';
            bodystr := '';
            bodystr := bodystr + 'code='+ds.FieldByName('AUTHORIZATIONCODE').Value+'&';
            bodystr := bodystr + 'client_id='+ds.FieldByName('CLIENTID').Value+'&';
            bodystr := bodystr + 'client_secret='+ds.FieldByName('CLIENTSECRET').Value+'&';
            bodystr := bodystr + 'redirect_uri='+redirURIsText+'&';
            bodystr := bodystr + 'grant_type=authorization_code';

            body := PAnsiChar(bodystr);
            ReqResult := HttpSendRequestA(hRequest, hdr, Length(hdr), body, Length(body));
            if not ReqResult then begin
              LastErrorGMail := 'Ошибка получения данных (1)';
              tr.Rollback;
              Exit;
            end;

            if GetResponseState(hRequest)<>'200' then begin
              bodystr := GetResponseBody(hRequest);
              LastErrorGMail := 'Ошибка запроса (1)' + #13#10 + bodystr;
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
              LastErrorGMail := 'Ошибка обработки ответа (1)';
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
        if tr.InTransaction then tr.Rollback;
        Result := False;
        LastErrorGMail := 'Фатальная ошибка (1)';
      end;
    end;
  finally
    Adm.CloseTR(tr);
    Adm.CloseDS(ds);
  end;
end;

function GetNewToken: string;
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
      LastErrorGMail := 'Ошибка интернета #1';
      Exit;
    end;

    hConnection := InternetConnectA(PInetHandle, PAnsiChar('accounts.google.com'),
                                    INTERNET_DEFAULT_HTTPS_PORT,
                                    nil, nil, INTERNET_SERVICE_HTTP, 0, 1);
    try
      if hConnection=nil then begin
        LastErrorGMail := 'Ошибка интернета #2';
        Exit;
      end;

      SetLength(AcceptTypes, 4);
      AcceptTypes[0] := PChar('application/x-www-form-urlencoded');
      AcceptTypes[1] := PChar('application/*');
      AcceptTypes[2] := PChar('text/*');
      AcceptTypes[3] := nil;
      hRequest := HttpOpenRequestA(hConnection, PAnsiChar('POST'), PAnsiChar('/o/oauth2/token'), nil, nil, Pointer(AcceptTypes),
                                   INTERNET_FLAG_SECURE,
                                   1);
      try
        if hRequest=nil then begin
          LastErrorGMail := 'Ошибка интернета #3';
          Exit;
        end;

        hdr := 'Content-Type: application/x-www-form-urlencoded';
        bodystr := '';
        bodystr := bodystr + 'refresh_token='+RefreshToken+'&';
        bodystr := bodystr + 'client_id='+ClientID+'&';
        bodystr := bodystr + 'client_secret='+ClientSecret+'&';
        bodystr := bodystr + 'grant_type=refresh_token';

        body := PAnsiChar(bodystr);
        ReqResult := HttpSendRequestA(hRequest, hdr, Length(hdr), body, Length(body));
        if not ReqResult then begin
          LastErrorGMail := 'Ошибка интернета #4';
          Exit;
        end;

        if GetResponseState(hRequest)<>'200' then begin
          LastErrorGMail := 'Не успешный запрос #1';
          bodystr := GetResponseBody(hRequest);
          LastErrorGMail := LastErrorGMail + #13#10 + bodystr;
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

function ReadToken(AForceGetToken: boolean = False): string;
var
  ds: TpFIBDataSet;
  tr: TpFIBTransaction;
  LastTokenTime: TDateTime;
  Expiration: integer;
  NewTokenContent: WideString;
  jsonObj: ISuperObject;
begin
  Result := '';
  ds := dbmTrans.CreateDS;
  tr := dbmTrans.CreateTr(trSingleLockTrans);
  try
    ds.Transaction := tr;
    ds.UpdateTransaction := tr;
    try
      tr.StartTransaction;
      ds.SelectSQL.Text := 'select * from gmail';
      ds.AutoUpdateOptions.KeyFields := 'GMAILID';
      ds.AutoUpdateOptions.UpdateTableName := 'GMAIL';
      ds.Open;
      ds.First;
      LastTokenTime := ds.FieldByName('ReceiveTime').AsDateTime;
      Expiration    := ds.FieldByName('Expires').AsInteger;
      RefreshToken  := ds.FieldByName('RefreshToken').AsString;
      TokenType     := ds.FieldByName('TokenType').AsString;
      ClientID      := ds.FieldByName('ClientID').AsString;
      ClientSecret  := ds.FieldByName('ClientSecret').AsString;
      UserEmail     := StringReplace(VarAsAStr(ds['UserEmail']), '@', '%40', []);

      if ((LastTokenTime+(Expiration/(24*60*60))) < (Now()+(5/(24*60)))) or AForceGetToken then begin
        NewTokenContent := GetNewToken;
        if NewTokenContent='' then begin
          LastErrorGMail := 'Ошибка получения нового токена #1';
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
          LastErrorGMail := 'Ошибка получения токена #2';
        end;
      end;

      tr.Commit;
    except
      if tr.InTransaction then tr.Rollback;
      raise;
    end;
  finally
    dbmTrans.CloseTR(tr);
    dbmTrans.CloseDS(ds);
  end;
end;

function CreateDraft(Receiver: string; Subject: string; Attachments: TStringList; var NeedNewToken: boolean): boolean; overload;
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
  answerText: WideString;
  boundary: string;
  i: integer;

  jsonObj: ISuperObject;
  errorObj: ISuperObject;
  theError: ISuperObject;
begin
  Result := False;
  NeedNewToken := False;
  AccessToken := ReadToken;
  if AccessToken = '' then begin
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
      LastErrorGMail := 'Ошибка интернета #5';
      Exit;
    end;

    hConnection := InternetConnectA(PInetHandle, PAnsiChar('www.googleapis.com'),
                                    INTERNET_DEFAULT_HTTPS_PORT,
                                    nil, nil, INTERNET_SERVICE_HTTP, 0, 1);
    try
      if hConnection=nil then begin
        LastErrorGMail := 'Ошибка интернета #6';
        Exit;
      end;

      SetLength(AcceptTypes, 4);
      AcceptTypes[0] := PChar('application/x-www-form-urlencoded');
      AcceptTypes[1] := PChar('application/*');
      AcceptTypes[2] := PChar('text/*');
      AcceptTypes[3] := nil;
      hRequest := HttpOpenRequestA(hConnection, PAnsiChar('POST'),
                                   PAnsiChar('/upload/gmail/v1/users/'+
                                             UserEmail+
                                             '/drafts?uploadType=multipart'), nil, nil, Pointer(AcceptTypes),
                                   INTERNET_FLAG_SECURE,
                                   1);
      try
        if hRequest=nil then begin
          LastErrorGMail := 'Ошибка интернета #7';
          Exit;
        end;

        boundary := 'TransA_B4C5A99F6C2C4C59B19B6DCAE2F8A33A';

        bodystr := Format('To: %s'+#13#10+
                          'Subject: %s'+#13#10+
                          'Content-Type: multipart/related; boundary=%s'+#13#10+
                          #13#10,
                          [Receiver, Subject, boundary]
                         );

        bodystr := bodystr + Format('--%s'+#13#10+
                                    'Content-Type: text/plain; charset="UTF-8"'+#13#10+
                                    #13#10,
                                    [boundary]
                                   );

        for i := 0 to Attachments.Count - 1 do begin
          bodystr := bodystr + Format('--%s'+#13#10+
                                      'Content-Type: image/jpeg; name="%s"'+#13#10+
                                      'Content-Disposition: attachment; filename="%s"'+#13#10+
                                      'Content-Transfer-Encoding: base64'+#13#10#13#10+
                                      '%s'+#13#10,
                                      [boundary, Attachments.Names[i], Attachments.Names[i],
                                       Attachments.ValueFromIndex[i]]
                                     );
        end;
        bodystr := bodystr + '--'+boundary+'--';

        body := PAnsiChar(bodystr);

        hdrstr := '';
        hdrstr := hdrstr + 'Authorization: Bearer '+AccessToken + #13#10;
        hdrstr := hdrstr + 'Content-Type: message/rfc822' + #13#10;
        //hdrstr := hdrstr + 'Content-Type: multipart/related; boundary='+boundary + #13#10;
        //hdrstr := hdrstr + 'Content-Length: '+IntToStr(Length(bodystr));
        hdr := PAnsiChar(hdrstr);

        ReqResult := HttpSendRequestA(hRequest, hdr, Length(hdr), body, Length(body));
        if not ReqResult then begin
          LastErrorGMail := 'Ошибка интернета #8';
          Exit;
        end;

        if GetResponseState(hRequest)='200' then begin
          Result := True;
        end else begin
          LastErrorGMail := 'Не успешный запрос #2';
          // проверка тела на ошибки
          answerText := GetResponseBody(hRequest);
          LastErrorGMail := LastErrorGMail + #13#10 + answerText;
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

function CreateDraft(Receiver: string; Subject: string; Attachments: TStringList): boolean; overload;
var
  NeedNewToken: boolean;
begin
  LastErrorGMail := '';
  Result := CreateDraft(Receiver, Subject, Attachments, NeedNewToken);
  if (not Result) and NeedNewToken then begin
    if ReadToken(True)<>'' then
      Result := CreateDraft(Receiver, Subject, Attachments, NeedNewToken);
  end;
end;

end.

