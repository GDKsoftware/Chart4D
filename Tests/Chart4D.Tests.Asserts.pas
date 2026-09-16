{*******************************************************}
{                                                       }
{       Chart4D Library - Editorial data charts         }
{                                                       }
{          Copyright(c) 2026 GDK Software               }
{                All rights reserved                    }
{                                                       }
{             Licensed under MIT License                }
{                                                       }
{*******************************************************}
unit Chart4D.Tests.Asserts;

/// <summary>
/// Extends DUnitX's <c>Assert</c> for the Chart4D fixtures. On 64-bit targets <c>Length</c>
/// and the <c>Count</c> of the generic collections return <c>NativeInt</c>, so
/// <c>Assert.AreEqual(3, Length(Values))</c> cannot infer the generic type argument. The
/// overload below accepts that pairing. On Win32 <c>NativeInt</c> is <c>Integer</c> and the
/// helper adds nothing. Delphi applies only one class helper per class, so a fixture that
/// uses this unit must not bring another helper for <c>Assert</c> into scope.
/// </summary>

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>Adds the <c>Integer</c> versus <c>NativeInt</c> <c>AreEqual</c> overload on 64-bit targets.</summary>
  TChart4DAssertHelper = class helper for Assert
  public
{$IFDEF CPU64BITS}
    class procedure AreEqual(const Expected: Integer; const Actual: NativeInt;
                             const Message: string = ''); overload;
{$ENDIF}
  end;

implementation

{$IFDEF CPU64BITS}
class procedure TChart4DAssertHelper.AreEqual(const Expected: Integer; const Actual: NativeInt;
                                              const Message: string);
begin
  Assert.AreEqual<NativeInt>(Expected, Actual, Message);
end;
{$ENDIF}

end.
