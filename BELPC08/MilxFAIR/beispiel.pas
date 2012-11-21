unit PciMilTreiber;

interface

procedure DriverOpen (var CardNr: Integer);
procedure DriverClose(var CardNr: Integer);

implementation

procedure DriverOpen;  external 'PCIMilDriver';
procedure DriverClose; external 'PCIMilDriver';

end.