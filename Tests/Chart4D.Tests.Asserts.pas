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
/// overload below accepts that pairing. On 32-bit targets <c>NativeInt</c> is
/// <c>Integer</c>, the overload would repeat an existing one, and this unit declares
/// nothing at all. Delphi applies only one class helper per class, so a 64-bit fixture
/// that uses this unit must not bring another helper for <c>Assert</c> into scope.
/// </summary>

interface

{$IFDEF CPU64BITS}
uses
  DUnitX.TestFramework;

type
  /// <summary>Adds the <c>Integer</c> versus <c>NativeInt</c> <c>AreEqual</c> overload.</summary>
  TChart4DAssertHelper = class helper for Assert
  public
    class procedure AreEqual(const Expected: Integer; const Actual: NativeInt;
                             const Message: string = ''); overload;
  end;
{$ENDIF}

implementation

{$IFDEF CPU64BITS}
class procedure TChart4DAssertHelper.AreEqual(const Expected: Integer; const Actual: NativeInt;
                                              const Message: string);
begin
  Assert.AreEqual<NativeInt>(Expected, Actual, Message);
end;
{$ENDIF}

end.
