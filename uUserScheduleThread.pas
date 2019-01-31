unit uUserScheduleThread;

interface
uses
  Classes, SysUtils, uDB, SuperObject;

type
  TOnTransmitMessage = procedure (AMsg: string) of object;

  TUserScheduleThread = class(TThread)
  private
    dm: TdbmDental;
  protected
    procedure Execute; override;
  public
    UserID: integer;
    UserName: string;
    CalendarID: widestring;
    OnTransmitMessage: TOnTransmitMessage;
    constructor Create(CreateSuspended: Boolean);
    destructor Destroy; override;
    procedure ProcessEvents;
  end;

implementation

uses
  Windows, GoogleCalendarAPI, pFIBDataSet, PFIBDatabase, RegExpr, uConstants,
    Variants, uCommonDefinitions, DentalDateUtils;

{ TUserScheduleThread }

constructor TUserScheduleThread.Create(CreateSuspended: Boolean);
begin
  inherited;
  dm := TdbmDental.Create(nil);
end;

destructor TUserScheduleThread.Destroy;
begin
  if Assigned(dm) then dm.Free;
  inherited;
end;

procedure TUserScheduleThread.Execute;
var
  t: TDateTime;
begin
  t := Now() - Random(300)/(24*60*60); // ������������ ������ �� �������, ����� ��� ����� �� �������� � ���� ������������
  repeat
    try
      if (Now()-t) > (15/(24*60)) then begin
        OnTransmitMessage('��������� ����� ������ � ���������, ������ '+UserName);

        // ������ �������� ��������
        ProcessEvents;

        t := Now();
        Sleep(1000);
        OnTransmitMessage('���������� ����� ������ � ���������, ������ '+UserName);
      end;
    except
      on E:Exception do begin
        OnTransmitMessage('������: '+E.Message+', ������ '+UserName);
      end;
    end;
    Sleep(100);
  until Terminated;
end;

procedure TUserScheduleThread.ProcessEvents;
const
  rTime3339 = '(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(\.\d+)*';
var
  jsonEventsSource: widestring;
  jsonEvents, jsonEvent: ISuperObject;
  jsonEventItems: TSuperArray;
  ie: integer;
  dsSched: TpFIBDataSet;
  tr: TpFIBtransaction;

  jName: widestring;
  jPatID, jStatus: integer;
  jDate, jTime, jDateTime: TDateTime;
  jTimeInt: integer;
  jDateTimeSrc: string;
  r: TRegExpr;
  DeleteInCalendar: boolean;
  FoundInCalendar: boolean;
  IdxEvent: integer;
  jsonSetEvent: ISuperObject;
  wtStatus: integer;
  URL: string;

  function TranslateDateTimeFrom3339(ASourceTime: string): TDateTime;
  var
    Bias: integer;
    BiasSign: string;
  begin
    Result := 0;
    r.Expression := rTime3339 + 'Z';
    if r.Exec(ASourceTime) then begin
      Result := EncodeDate(StrToInt(r.Match[1]), StrToInt(r.Match[2]), StrToInt(r.Match[3])) +
                EncodeTime(StrToInt(r.Match[4]), StrToInt(r.Match[5]), StrToInt(r.Match[6]), StrToIntDef(r.Match[7],0));
      Result := Result - CrazyFuckRealBias;
      Exit;
    end;

    r.Expression := rTime3339 + '([-+])(\d{2}):(\d{2})';
    if r.Exec(ASourceTime) then begin
      Result := EncodeDate(StrToInt(r.Match[1]), StrToInt(r.Match[2]), StrToInt(r.Match[3])) +
                EncodeTime(StrToInt(r.Match[4]), StrToInt(r.Match[5]), StrToInt(r.Match[6]), StrToIntDef(r.Match[7],0));
      // ������� ���. ����� ������������ ��� � ���������. Bias ������ ��� �������?!
      //Result := Result + StrToInt(r.Match[8]+r.Match[9])/24 + StrToInt(r.Match[10])/(24*60);
      Exit;
    end;
  end;

  function GetSummary(AName, AUselok: string): string;
  begin
    Result := UTF8Encode(Trim(AName + ' ' + AUselok));
  end;

  procedure FillSetEvent;
  begin
    jsonSetEvent.B['reminders.useDefault'] := False;
    jsonSetEvent.O['reminders.overrides'] := SO('[]');
    jsonSetEvent.S['start.dateTime'] := CrazyFuckLocalTimeToRTF3339(
                                          FieldValueToDateType(dsSched.FieldByName('wdate').Value)+
                                          FieldValueToTimeType(dsSched.FieldByName('wtime').Value)/(24*60*60*1000)
                                        );
    // +5 �����
    jsonSetEvent.S['end.dateTime'] := CrazyFuckLocalTimeToRTF3339(
                                        FieldValueToDateType(dsSched.FieldByName('wdate').Value)+
                                        (FieldValueToTimeType(dsSched.FieldByName('wtime').Value)+15*60*1000)/(24*60*60*1000)
                                      );

    if wtStatus=ttsDontBusy then begin
      jsonSetEvent.S['summary'] := UTF8Encode(ttStrDontBusy);
    end else begin
      jsonSetEvent.S['summary'] := GetSummary(VariantAsWideString(dsSched.FieldByName('PtName').Value),
                                              VariantAsWideString(dsSched.FieldByName('Uselok').Value));
    end;

    jsonSetEvent.I['extendedProperties.shared.patid']  := VariantAsIDentifier(dsSched.FieldByName('PatID').Value);
    jsonSetEvent.I['extendedProperties.shared.status'] := wtStatus;
  end;

begin
  if not GetCalendarItems(dm, CalendarID, jsonEventsSource) then begin
    OnTransmitMessage('������: '+GetLastErrorGoogleCalendar+', ������ '+UserName);
    Exit;
  end;

  { ��� 0. ������� ��������� }
  jsonEvents := SO(jsonEventsSource);
  jsonEventItems := jsonEvents.A['items'];

  tr := dm.CreateTr;
  dsSched := dm.CreateDS;
  r  := TRegExpr.Create;
  try
    tr.StartTransaction;
    dsSched.Transaction := tr;
    dsSched.UpdateTransaction := tr;
    dsSched.SelectSQL.Text := 'select * from worktable '+
                              'where (userid = :userid) '+
                                    'and (wdate >= :wdate) '+
                              'order by wdate, wtime';
    dsSched.ParamByName('userid').Value := UserID;
    dsSched.ParamByName('wdate').AsDate := CurrentDate();
    dsSched.Open;

    { ��� 1. �������� �� ��������� � ������� ��, ���� ��� � ����������}
    for ie:=0 to jsonEventItems.Length-1 do begin
      jsonEvent := jsonEventItems.O[ie];
      jName  := jsonEvent.S['summary'];
      jPatID := jsonEvent.I['extendedProperties.shared.patid'];
      jStatus := jsonEvent.I['extendedProperties.shared.status'];

      jDateTimeSrc := jsonEvent.S['start.dateTime'];
      jDateTime := TranslateDateTimeFrom3339(jDateTimeSrc);

      if jDateTime=0 then begin
        OnTransmitMessage('������: '+'�� ���������� ����� '+jDateTimeSrc+', ������ '+UserName);
        Continue;
      end;

      jDate := Trunc(jDateTime);
      jTime := Frac(jDateTime);
      jTimeInt := Trunc(jTime*24*60*60*1000);

      DeleteInCalendar := False;
      if dsSched.Locate('WDATE;WTIME', VarArrayOf([jDate,jTimeInt]), []) then begin
        if (jStatus=ttsDontBusy) and (VariantAsInteger(dsSched.FieldByName('Status').Value,-1)=ttsDontBusy) then
        begin
          // ���� ��� ������� "�� ��������", �� ������ �� ������ � ���� �������
        end else begin
          if (VariantAsInteger(dsSched.FieldByName('Status').Value,-1) in [ttsWork, ttsNotWork])
             and (VariantAsIDentifier(dsSched.FieldByName('PatID').Value)=UndefiniteID)
             and (VariantAsWideString(dsSched.FieldByName('PtName').Value)='')
             and (VariantAsWideString(dsSched.FieldByName('Uselok').Value)='')
          then
            DeleteInCalendar := True;
        end;

      end else
        DeleteInCalendar := True;

      if DeleteInCalendar then
        if not DeleteEvent(dm, CalendarID, jsonEvent.S['id']) then
          OnTransmitMessage(Format('������: �� ������� ������ %s, ������ %s',
                                   [FormatDateTime('dd.mm.yy hh:nn', jDateTime), UserName]));
    end;

    { ��� 2. �������� �� ���������� � ������� ��, ���� ��� � ���������.
             ��� �� ��������� �� ������������ ��, ��� ���� � ���������}
    dsSched.First;
    while not dsSched.Eof do begin
      wtStatus := VariantAsInteger(dsSched.FieldByName('Status').Value,-1);

      FoundInCalendar := False;
      for ie:=0 to jsonEventItems.Length-1 do begin
        jsonEvent := jsonEventItems.O[ie];
        jName  := jsonEvent.S['summary'];
        jPatID := jsonEvent.I['extendedProperties.shared.patid'];
        jStatus := jsonEvent.I['extendedProperties.shared.status'];

        jDateTimeSrc := jsonEvent.S['start.dateTime'];
        jDateTime := TranslateDateTimeFrom3339(jDateTimeSrc);

        if jDateTime=0 then begin
          OnTransmitMessage('������: '+'�� ���������� ����� '+jDateTimeSrc+', ������ '+UserName);
          dsSched.Next;
          Continue;
        end;

        jDate := Trunc(jDateTime);
        jTime := Frac(jDateTime);
        jTimeInt := Trunc(jTime*24*60*60*1000);

        if (jDate = FieldValueToDateType(dsSched.FieldByName('wdate').Value))
           and (jTimeInt = FieldValueToTimeType(dsSched.FieldByName('wtime').Value))
        then begin
          FoundInCalendar := True;
          IdxEvent := ie;
          Break;
        end;
      end;


      jsonSetEvent := SO('{}');
      try
        if FoundInCalendar then begin
          if (jStatus=ttsDontBusy) and (wtStatus=ttsDontBusy) then
          begin
            // ���� ��� ������� "�� ��������", �� ������ �� ������ � ���� �������?
            // ��� ������ ������ ���������
          end else begin
            // ���� ���-�� �� ���������, �� ��������
            if (jName <> GetSummary(VariantAsWideString(dsSched.FieldByName('PtName').Value),
                                    VariantAsWideString(dsSched.FieldByName('Uselok').Value)))
               or (jPatID <> VariantAsIDentifier(dsSched.FieldByName('PatID').Value))
               or (jStatus <> wtStatus)
            then begin
              FillSetEvent;
              URL := '/calendar/v3/calendars/' + CalendarId + '/events/'+jsonEvent.S['id'];
              if not AddUpdateEvent(dm, 'PUT', URL, jsonSetEvent) then
                OnTransmitMessage(Format('������: �� �������� ������ %s, ������ %s',
                                         [FormatDateTime('dd.mm.yy hh:nn', jDateTime), UserName]));
            end;
          end;
        end else begin
          // ��� � ���������. ���� ��������
          // � ��� �������� ����� �� ��� ������, ���� ������ ���������� ������ "�� ��������", � ����� "������� �����"
          // ��� �������� ������� ����������, � ����� �������. � ����� ������� ������ ������������ � ������� ���������, �� ������. 
          if (VariantAsInteger(dsSched.FieldByName('Status').Value,-1) = ttsDontBusy)
             or (VariantAsIDentifier(dsSched.FieldByName('PatID').Value) <> UndefiniteID)
                or (VariantAsWideString(dsSched.FieldByName('PtName').Value) <> '')
                or (VariantAsWideString(dsSched.FieldByName('Uselok').Value) <> '')
          then begin
            FillSetEvent;
            URL := '/calendar/v3/calendars/' + CalendarId + '/events';
            if not AddUpdateEvent(dm, 'POST', URL, jsonSetEvent) then
              OnTransmitMessage(Format('������: �� ��������� ������ %s, ������ %s',
                                       [FormatDateTime('dd.mm.yy hh:nn', FieldValueToDateType(dsSched.FieldByName('wdate').Value)),
                                        UserName]));
          end;
        end;
      finally
        jsonSetEvent := nil;
      end;

      dsSched.Next;
    end;

  finally
    r.Free;
    dm.CloseDS(dsSched);
    dm.CloseTR(tr);
  end;
end;

end.

